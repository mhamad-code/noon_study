import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:noon_study/alarms.dart';
import 'package:noon_study/data.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

void main() {
  late tz.TZDateTime now; // Wednesday 2026-10-21 10:00 UTC

  setUpAll(() {
    tzdata.initializeTimeZones();
    now = tz.TZDateTime(tz.UTC, 2026, 10, 21, 10, 0);
  });

  test('later today is returned for the same weekday', () {
    final r = AlarmService.nextOccurrence(3, '11:00', now)!;
    expect(r.day, 21);
    expect(r.hour, 11);
  });

  test('time already passed moves to next week', () {
    final r = AlarmService.nextOccurrence(3, '09:00', now)!;
    expect(r.month, 10);
    expect(r.day, 28);
  });

  test('exactly now is not scheduled in the past', () {
    final r = AlarmService.nextOccurrence(3, '10:00', now)!;
    expect(r.isAfter(now), isTrue);
    expect(r.day, 28);
  });

  test('other weekdays resolve to the next matching date', () {
    final sun = AlarmService.nextOccurrence(0, '07:00', now)!;
    expect(sun.day, 25);
    expect(sun.weekday % 7, 0);
    final sat = AlarmService.nextOccurrence(6, '23:30', now)!;
    expect(sat.day, 24);
  });

  test('month rollover works', () {
    final fri = tz.TZDateTime(tz.UTC, 2026, 10, 30, 23, 0);
    final r = AlarmService.nextOccurrence(0, '07:00', fri)!;
    expect(r.month, 11);
    expect(r.day, 1);
  });

  test('invalid time returns null', () {
    expect(AlarmService.nextOccurrence(3, 'abc', now), isNull);
    expect(AlarmService.nextOccurrence(3, '24:00', now), isNull);
  });

  test('plan creates unique future alarms for start and end', () {
    final s = Schedule.parse(jsonDecode(jsonEncode({
      'version': 1,
      'week': {
        'sunday': [
          {'subject': 'رياضيات', 'start': '07:00', 'end': '09:00'},
          {'subject': 'فيزياء', 'start': '09:30', 'end': '11:00'},
        ],
        'monday': [
          {'subject': 'إنجليزي', 'start': '08:00', 'end': '09:00'},
        ],
      },
    }))).schedule!;
    final plan = AlarmService.plan(s, now);
    expect(plan.length, 6);
    expect(plan.map((a) => a.id).toSet().length, 6);
    expect(plan.every((a) => a.when.isAfter(now)), isTrue);
    expect(plan.where((a) => a.start).length, 3);
  });

  test('lesson without end time creates only a start alarm', () {
    final s = Schedule.parse(jsonDecode(jsonEncode({
      'version': 1,
      'week': {
        'sunday': [
          {'subject': 'عربي', 'start': '18:00'},
        ],
      },
    }))).schedule!;
    expect(AlarmService.plan(s, now).length, 1);
  });
}
