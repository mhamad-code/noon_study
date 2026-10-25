import 'package:flutter_test/flutter_test.dart';
import 'package:noon_study/data.dart';

void main() {
  test('12-hour format', () {
    expect(fmt12('04:30'), '4:30 ص');
    expect(fmt12('00:15'), '12:15 ص');
    expect(fmt12('12:00'), '12:00 م');
    expect(fmt12('15:00'), '3:00 م');
    expect(fmt12('21:30'), '9:30 م');
    expect(fmt12('xx'), 'xx');
  });
}
