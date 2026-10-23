import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'alarms.dart';
import 'config.dart';
import 'net.dart';

const dayKeys = [
  'sunday', 'monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday'
];
const dayNames = [
  'الأحد', 'الإثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت'
];

final RegExp _timeRe = RegExp(r'^\s*([01]?\d|2[0-3]):([0-5]\d)\s*$');

/// "7:05" -> 425 ، وإذا الوقت غلط -> -1
int timeToMinutes(String t) {
  final m = _timeRe.firstMatch(t);
  if (m == null) return -1;
  return int.parse(m.group(1)!) * 60 + int.parse(m.group(2)!);
}

String _fmt(int mins) {
  final h = (mins ~/ 60).toString().padLeft(2, '0');
  final m = (mins % 60).toString().padLeft(2, '0');
  return '$h:$m';
}

class Lesson {
  final String subject, start, end, pages;
  Lesson({
    required this.subject,
    required this.start,
    required this.end,
    required this.pages,
  });

  static Lesson? parse(dynamic j, String at, List<String> errors) {
    if (j is! Map) {
      errors.add('$at: الدرس لازم يكون كائن');
      return null;
    }
    final subject = (j['subject'] ?? '').toString().trim();
    if (subject.isEmpty) {
      errors.add('$at: اسم المادة فاضي');
      return null;
    }
    final sm = timeToMinutes((j['start'] ?? '').toString());
    if (sm < 0) {
      errors.add('$at: وقت البداية غلط');
      return null;
    }
    final endRaw = (j['end'] ?? '').toString().trim();
    var end = '';
    if (endRaw.isNotEmpty) {
      final em = timeToMinutes(endRaw);
      if (em < 0 || em <= sm) {
        errors.add('$at: وقت النهاية غلط');
        return null;
      }
      end = _fmt(em);
    }
    return Lesson(
      subject: subject,
      start: _fmt(sm),
      end: end,
      pages: (j['pages'] ?? '').toString().trim(),
    );
  }
}

class ParseResult {
  final Schedule? schedule;
  final List<String> errors;
  ParseResult(this.schedule, this.errors);
}

class Schedule {
  final int version;
  final Map<String, List<Lesson>> week;
  Schedule(this.version, this.week);

  int get lessonCount => week.values.fold(0, (a, l) => a + l.length);

  /// بصمة المحتوى: بتتغير بس لما الجدول يتغير فعلياً
  String get signature {
    final b = StringBuffer();
    for (final k in dayKeys) {
      for (final l in week[k] ?? <Lesson>[]) {
        b.write('$k|${l.subject}|${l.start}|${l.end}|${l.pages};');
      }
    }
    return b.toString();
  }

  /// بيرجع جدول سليم، أو null مع قائمة الأخطاء
  static ParseResult parse(dynamic json) {
    if (json is! Map) {
      return ParseResult(null, ['الملف لازم يكون كائن JSON']);
    }
    final rawWeek = json['week'];
    if (rawWeek is! Map) {
      return ParseResult(null, ['الحقل week مفقود أو غلط']);
    }
    final errors = <String>[];
    var version = 0;
    final v = json['version'];
    if (v is num) {
      version = v.toInt();
    } else if (v != null) {
      errors.add('version لازم يكون رقم');
    }

    final week = <String, List<Lesson>>{};
    for (final k in dayKeys) {
      final raw = rawWeek[k];
      if (raw == null) {
        week[k] = <Lesson>[];
        continue;
      }
      if (raw is! List) {
        errors.add('$k لازم يكون قائمة');
        week[k] = <Lesson>[];
        continue;
      }
      if (raw.length > 40) {
        errors.add('$k فيه دروس كثيرة (الحد الأقصى 40)');
        week[k] = <Lesson>[];
        continue;
      }
      final lessons = <Lesson>[];
      for (int i = 0; i < raw.length; i++) {
        final l = Lesson.parse(raw[i], '$k #${i + 1}', errors);
        if (l != null) lessons.add(l);
      }
      lessons.sort(
          (a, b) => timeToMinutes(a.start).compareTo(timeToMinutes(b.start)));
      week[k] = lessons;
    }
    if (errors.isNotEmpty) return ParseResult(null, errors);
    return ParseResult(Schedule(version, week), errors);
  }
}

class ScheduleService {
  static const _cacheKey = 'schedule_json';

  /// آخر خطأ بالتحديث (null إذا ما في خطأ بالملف نفسه)
  static String? lastError;

  static Future<Schedule?> loadCached() async {
    try {
      final p = await SharedPreferences.getInstance();
      final s = p.getString(_cacheKey);
      if (s == null) return null;
      final sch = Schedule.parse(jsonDecode(s)).schedule;
      if (sch == null) return null;
      unawaited(AlarmService.ensureScheduled(sch));
      return sch;
    } catch (_) {
      return null;
    }
  }

  static Future<Schedule?> fetchRemote() async {
    try {
      final r = await downloadUpdate();
      if (r.statusCode != 200) {
        lastError = 'تعذر تحميل الملف (رمز ${r.statusCode})';
        return null;
      }
      final body = utf8.decode(r.bodyBytes);
      final parsed = Schedule.parse(jsonDecode(body));
      final sch = parsed.schedule;
      if (sch == null) {
        final why = parsed.errors.take(2).join(' · ');
        lastError = 'update.json فيه خطأ: $why. بنستخدم النسخة المحفوظة';
        return null;
      }
      final p = await SharedPreferences.getInstance();
      await p.setString(_cacheKey, body);
      lastError = null;
      unawaited(AlarmService.ensureScheduled(sch));
      return sch;
    } on FormatException {
      lastError = 'update.json مش بصيغة JSON صحيحة. بنستخدم النسخة المحفوظة';
      return null;
    } catch (_) {
      lastError = null;
      return null;
    }
  }
}
