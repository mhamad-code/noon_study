import 'dart:typed_data';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'data.dart';

class AlarmStatus {
  final bool notifications, exact;
  final int pending;
  AlarmStatus(this.notifications, this.exact, this.pending);
}

class AlarmService {
  static final _plugin = FlutterLocalNotificationsPlugin();

  static AndroidFlutterLocalNotificationsPlugin? get _android =>
      _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

  static Future<void> init() async {
    tzdata.initializeTimeZones();
    try {
      final name = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(name));
    } catch (_) {}
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );
    await _plugin.initialize(settings);
  }

  static Future<void> requestPermissions() async {
    await _android?.requestNotificationsPermission();
    await _android?.requestExactAlarmsPermission();
  }

  static Future<AlarmStatus> status() async {
    final n = await _android?.areNotificationsEnabled() ?? false;
    final e = await _android?.canScheduleExactNotifications() ?? false;
    final p = (await _plugin.pendingNotificationRequests())
        .where((r) => r.id != 9999)
        .length;
    return AlarmStatus(n, e, p);
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

  static tz.TZDateTime? _next(int day, String hhmm) {
    final p = hhmm.split(':');
    if (p.length < 2) return null;
    final h = int.tryParse(p[0]);
    final m = int.tryParse(p[1]);
    if (h == null || m == null) return null;
    final now = tz.TZDateTime.now(tz.local);
    var d = tz.TZDateTime(tz.local, now.year, now.month, now.day, h, m);
    while (d.weekday % 7 != day || !d.isAfter(now)) {
      d = tz.TZDateTime(tz.local, d.year, d.month, d.day + 1, h, m);
    }
    return d;
  }

  static Future<int> _one(int id, String title, String body,
      tz.TZDateTime? when, bool start, AndroidScheduleMode mode) async {
    if (when == null) return 0;
    await _plugin.zonedSchedule(
      id,
      title,
      body,
      when,
      _details(start),
      androidScheduleMode: mode,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
    );
    return 1;
  }

  /// يمسح المنبهات القديمة ويجدول منبهات الأسبوع من الجدول
  static Future<int> scheduleAll(Schedule s) async {
    try {
      await _plugin.cancelAll();
      final exact = await _android?.canScheduleExactNotifications() ?? false;
      final mode = exact
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle;
      int n = 0;
      for (int d = 0; d < 7; d++) {
        final lessons = s.week[dayKeys[d]] ?? <Lesson>[];
        for (int i = 0; i < lessons.length; i++) {
          final l = lessons[i];
          final range = '${l.start} – ${l.end}';
          n += await _one(
            d * 100 + i * 2,
            'حان وقت ${l.subject} 📖',
            l.pages.isEmpty ? range : '${l.pages}  ·  $range',
            _next(d, l.start),
            true,
            mode,
          );
          if (l.end.isNotEmpty) {
            n += await _one(
              d * 100 + i * 2 + 1,
              'انتهى وقت ${l.subject} ✅',
              'أحسنت! خذ استراحة',
              _next(d, l.end),
              false,
              mode,
            );
          }
        }
      }
      return n;
    } catch (_) {
      return -1;
    }
  }

  static Future<void> test() async {
    final exact = await _android?.canScheduleExactNotifications() ?? false;
    await _plugin.zonedSchedule(
      9999,
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
  }
}
