import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noon_study/data.dart';
import 'package:noon_study/main.dart';

void main() {
  testWidgets('LessonCard shows subject, time and pages', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: LessonCard(
          lesson: Lesson(
            subject: 'رياضيات',
            start: '07:00',
            end: '09:00',
            pages: 'ص 20 - 25',
          ),
          index: 0,
          live: false,
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('رياضيات'), findsOneWidget);
    expect(find.text('7:00 ص – 9:00 ص'), findsOneWidget);
    expect(find.text('ص 20 - 25'), findsOneWidget);
  });
}
