import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'config.dart';

const dayKeys = [
  'sunday', 'monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday'
];
const dayNames = [
  'الأحد', 'الإثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت'
];

class Lesson {
  final String subject, start, end, pages;
  Lesson({
    required this.subject,
    required this.start,
    required this.end,
    required this.pages,
  });

  factory Lesson.fromJson(Map<String, dynamic> j) => Lesson(
        subject: (j['subject'] ?? '').toString(),
        start: (j['start'] ?? '').toString(),
        end: (j['end'] ?? '').toString(),
        pages: (j['pages'] ?? '').toString(),
      );
}

class Schedule {
  final int version;
  final Map<String, List<Lesson>> week;
  Schedule(this.version, this.week);

  factory Schedule.fromJson(Map<String, dynamic> j) {
    final w = <String, List<Lesson>>{};
    final raw = (j['week'] ?? {}) as Map<String, dynamic>;
    for (final k in dayKeys) {
      final list = (raw[k] ?? []) as List;
      final lessons = list
          .map((e) => Lesson.fromJson(e as Map<String, dynamic>))
          .toList();
      lessons.sort((a, b) => a.start.compareTo(b.start));
      w[k] = lessons;
    }
    return Schedule((j['version'] ?? 0) as int, w);
  }
}

class ScheduleService {
  static const _cacheKey = 'schedule_json';

  static Future<Schedule?> loadCached() async {
    try {
      final p = await SharedPreferences.getInstance();
      final s = p.getString(_cacheKey);
      if (s == null) return null;
      return Schedule.fromJson(jsonDecode(s) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  static Future<Schedule?> fetchRemote() async {
    try {
      final r = await http
          .get(Uri.parse(updateUrl))
          .timeout(const Duration(seconds: 15));
      if (r.statusCode != 200) return null;
      final body = utf8.decode(r.bodyBytes);
      final sch = Schedule.fromJson(jsonDecode(body) as Map<String, dynamic>);
      final p = await SharedPreferences.getInstance();
      await p.setString(_cacheKey, body);
      return sch;
    } catch (_) {
      return null;
    }
  }
}
