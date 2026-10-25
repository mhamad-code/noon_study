import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'data.dart';

class AlarmStatus {
  final bool notifications, exact;
  final int pending;
  AlarmStatus(this.notifications, this.exact, this.pending);
}

class PlannedAlarm {
  final int id;
  final String title, body;
  final tz.TZDateTime when;
  final bool start;
  PlannedAlarm(this.id, this.title, this.body, this.when, this.start);
}

class ScheduleOutcome {
  final int planned, scheduled;
  final String? warning;
  ScheduleOutcome(this.planned, this.scheduled, this.warning);
  bool get ok => scheduled == planned;
}

class AlarmService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static const _sigKey = 'alarm_signature';
  static const _testId = 9999;

  static ScheduleOutcome? last;
  static Future<void> _queue = Future<void>.value();

  static AndroidFlutterLocalNotificationsPlugin? get _android =>
      _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

  static Future<void> init() async {
    tzdata.initializeTimeZones();
    try {
      final name = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(name));
    } catch (_) {
      _fallbackLocation();
    }
    try {
      await _plugin.initialize(const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ));
    } catch (_) {}
  }

  static void _fallbackLocation() {
    final off = DateTime.now().timeZoneOffset.inMilliseconds;
    final ms = DateTime.now().millisecondsSinceEpoch;
    for (final loc in tz.timeZoneDatabase.locations.values) {
      if (loc.timeZone(ms).offset == off) {
        tz.setLocalLocation(loc);
        return;
      }
    }
  }

  static Future<void> requestPermissions() async {
    try {
      await _android?.requestNotificationsPermission();
      await _android?.requestExactAlarmsPermission();
    } catch (_) {}
  }

  static Future<int> _pendingCount() async {
    final list = await _plugin.pendingNotificationRequests();
    return list.where((r) => r.id != _testId).length;
  }

  static Future<AlarmStatus> status() async {
    try {
      final n = await _android?.areNotificationsEnabled() ?? false;
      final e = await _android?.canScheduleExactNotifications() ?? false;
      return AlarmStatus(n, e, await _pendingCount());
    } catch (_) {
      return AlarmStatus(false, false, 0);
    }
  }

  static NotificationDetails _details(bool start) {
    return NotificationDetails(
      android: AndroidNotificationDetails(
        start ? 'noon_start_v1' : 'noon_end_v1',
        start ? 'بداية الدرس' : 'نهاية الدرس',
        channelDescription: 'منبهات جدول الدراسة',
        importance: Importance.max,
        priority: Priority.max,
        category: AndroidNotificationCategory.alarm,
        audioAttributesUsage: AudioAttributesUsage.alarm,
        sound: start
            ? const UriAndroidNotificationSound(
                'content://settings/system/alarm_alert')
            : null,
        playSound: true,
        enableVibration: true,
        vibrationPattern: Int64List.fromList([0, 700, 350, 700, 350, 700]),
        fullScreenIntent: true,
        visibility: NotificationVisibility.public,
        timeoutAfter: start ? 90000 : 30000,
        additionalFlags: Int32List.fromList(<int>[4]),
        autoCancel: true,
      ),
    );
  }

  /// أقرب موعد قادم (بعد now) لليوم day (الأحد=0) والوقت hhmm
  static tz.TZDateTime? nextOccurrence(
      int day, String hhmm, tz.TZDateTime now) {
    final mins = timeToMinutes(hhmm);
    if (mins < 0) return null;
    final h = mins ~/ 60;
    final m = mins % 60;
    var d = tz.TZDateTime(now.location, now.year, now.month, now.day, h, m);
    for (int i = 0; i < 8; i++) {
      if (d.weekday % 7 == day && d.isAfter(now)) return d;
      d = tz.TZDateTime(now.location, d.year, d.month, d.day + 1, h, m);
    }
    return null;
  }

  /// بيحسب كل منبهات الأسبوع (بدون ما يجدول شي)
  static List<PlannedAlarm> plan(Schedule s, tz.TZDateTime now) {
    final out = <PlannedAlarm>[];
    for (int d = 0; d < 7; d++) {
      final lessons = s.week[dayKeys[d]] ?? <Lesson>[];
      for (int i = 0; i < lessons.length; i++) {
        final l = lessons[i];
        final range = fmtRange(l);
        final a = nextOccurrence(d, l.start, now);
        if (a != null) {
          out.add(PlannedAlarm(
            d * 100 + i * 2,
            'حان وقت ${l.subject} 📖',
            l.pages.isEmpty ? range : '${l.pages}  ·  $range',
            a,
            true,
          ));
        }
        if (l.end.isNotEmpty) {
          final b = nextOccurrence(d, l.end, now);
          if (b != null) {
            out.add(PlannedAlarm(
              d * 100 + i * 2 + 1,
              'انتهى وقت ${l.subject} ✅',
              'أحسنت! خذ استراحة',
              b,
              false,
            ));
          }
        }
      }
    }
    return out;
  }

  /// بيتأكد إن المنبهات مطابقة للجدول. ما بيعيد الجدولة إلا إذا لزم
  static Future<ScheduleOutcome> ensureScheduled(Schedule s,
      {bool force = false}) {
    final c = Completer<ScheduleOutcome>();
    _queue = _queue.then((_) async {
      try {
        c.complete(await _ensure(s, force));
      } catch (e) {
        final o = ScheduleOutcome(0, 0, 'خطأ بالجدولة: $e');
        last = o;
        c.complete(o);
      }
    });
    return c.future;
  }

  static Future<ScheduleOutcome> _ensure(Schedule s, bool force) async {
    final now = tz.TZDateTime.now(tz.local);
    final planned = plan(s, now);
    final android = _android;
    final notifOn = await android?.areNotificationsEnabled() ?? true;
    final exact = await android?.canScheduleExactNotifications() ?? false;

    final warns = <String>[];
    if (!notifOn) warns.add('إشعارات التطبيق مغلقة، فعّلها من زر الجرس');
    if (!exact) warns.add('المنبهات الدقيقة غير مفعّلة، ممكن يتأخر المنبه');

    final sig = '${s.signature}|exact=$exact|tz=${tz.local.name}|fmt=12h';
    final prefs = await SharedPreferences.getInstance();
    final pending = await _pendingCount();

    if (!force &&
        prefs.getString(_sigKey) == sig &&
        pending == planned.length) {
      final o = ScheduleOutcome(
          planned.length, pending, warns.isEmpty ? null : warns.join(' · '));
      last = o;
      return o;
    }

    await _plugin.cancelAll();
    final mode = exact
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle;
    String? firstErr;
    for (final a in planned) {
      try {
        await _plugin.zonedSchedule(
          a.id,
          a.title,
          a.body,
          a.when,
          _details(a.start),
          androidScheduleMode: mode,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
        );
      } catch (e) {
        firstErr ??= e.toString();
      }
    }

    final scheduled = await _pendingCount();
    if (scheduled == planned.length) {
      await prefs.setString(_sigKey, sig);
    } else {
      await prefs.remove(_sigKey);
      final missing = planned.length - scheduled;
      warns.insert(
          0, 'فشلت جدولة $missing منبه' + (firstErr == null ? '' : ' ($firstErr)'));
    }
    final o = ScheduleOutcome(
        planned.length, scheduled, warns.isEmpty ? null : warns.join(' · '));
    last = o;
    return o;
  }

  /// بيرجع null إذا نجحت الجدولة، أو نص الخطأ
  static Future<String?> test() async {
    try {
      final exact = await _android?.canScheduleExactNotifications() ?? false;
      await _plugin.zonedSchedule(
        _testId,
        'تجربة منبه NOON ⏰',
        'إذا سمعت هالصوت فالمنبه شغّال',
        tz.TZDateTime.now(tz.local).add(const Duration(seconds: 10)),
        _details(true),
        androidScheduleMode: exact
            ? AndroidScheduleMode.exactAllowWhileIdle
            : AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
      return null;
    } catch (e) {
      return e.toString();
    }
  }
}
