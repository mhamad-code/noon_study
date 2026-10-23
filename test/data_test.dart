import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:noon_study/data.dart';

dynamic _json(Map<String, dynamic> m) => jsonDecode(jsonEncode(m));

Map<String, dynamic> _raw() => {
      'version': 2,
      'week': {
        'sunday': [
          {
            'subject': 'رياضيات',
            'start': '7:00',
            'end': '09:00',
            'pages': 'ص 20 - 25'
          },
          {'subject': 'فيزياء', 'start': '09:30', 'end': '11:00', 'pages': 5},
        ],
      },
    };

Map<String, dynamic> _base() =>
    jsonDecode(jsonEncode(_raw())) as Map<String, dynamic>;

void main() {
  test('valid schedule parses and normalizes times', () {
    final r = Schedule.parse(_json(_base()));
    expect(r.errors, isEmpty);
    final lessons = r.schedule!.week['sunday']!;
    expect(lessons.length, 2);
    expect(lessons.first.start, '07:00');
    expect(lessons[1].pages, '5');
    expect(r.schedule!.week['monday'], isEmpty);
    expect(r.schedule!.version, 2);
  });

  test('signature is stable for same content', () {
    final a = Schedule.parse(_json(_base())).schedule!;
    final b = Schedule.parse(_json(_base())).schedule!;
    expect(a.signature, b.signature);
  });

  test('non-object json is rejected', () {
    final r = Schedule.parse([1, 2, 3]);
    expect(r.schedule, isNull);
    expect(r.errors, isNotEmpty);
  });

  test('missing week is rejected', () {
    final r = Schedule.parse({'version': 1});
    expect(r.schedule, isNull);
  });

  test('invalid start time is rejected', () {
    final m = _base();
    (m['week']['sunday'][0] as Map)['start'] = '25:00';
    final r = Schedule.parse(_json(m));
    expect(r.schedule, isNull);
    expect(r.errors, isNotEmpty);
  });

  test('end before start is rejected', () {
    final m = _base();
    (m['week']['sunday'][0] as Map)['end'] = '06:00';
    expect(Schedule.parse(_json(m)).schedule, isNull);
  });

  test('empty subject is rejected', () {
    final m = _base();
    (m['week']['sunday'][0] as Map)['subject'] = '  ';
    expect(Schedule.parse(_json(m)).schedule, isNull);
  });

  test('non-numeric version is rejected', () {
    final m = _base();
    m['version'] = 'abc';
    expect(Schedule.parse(_json(m)).schedule, isNull);
  });

  test('day that is not a list is rejected', () {
    final m = _base();
    (m['week'] as Map)['monday'] = 'oops';
    expect(Schedule.parse(_json(m)).schedule, isNull);
  });

  test('timeToMinutes handles valid and invalid values', () {
    expect(timeToMinutes('07:05'), 425);
    expect(timeToMinutes('7:05'), 425);
    expect(timeToMinutes('24:00'), -1);
    expect(timeToMinutes('abc'), -1);
  });
}
