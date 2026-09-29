import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/calendar/widgets_schedule_datetime_dialog.dart';

void main() {
  final now = DateTime(2026, 9, 29, 14, 30);

  test('today keeps a recommendation time that is still in the future', () {
    final result = initialRecommendedScheduleTime(
      selectedDate: now,
      sourceTime: const TimeOfDay(hour: 18, minute: 0),
      currentDateTime: now,
    );

    expect(result, const TimeOfDay(hour: 18, minute: 0));
  });

  test('today replaces a past recommendation time with the current time', () {
    final result = initialRecommendedScheduleTime(
      selectedDate: now,
      sourceTime: const TimeOfDay(hour: 9, minute: 0),
      currentDateTime: now,
    );

    expect(result, const TimeOfDay(hour: 14, minute: 30));
  });

  test('a future date keeps its recommendation time', () {
    final result = initialRecommendedScheduleTime(
      selectedDate: DateTime(2026, 9, 30),
      sourceTime: const TimeOfDay(hour: 9, minute: 0),
      currentDateTime: now,
    );

    expect(result, const TimeOfDay(hour: 9, minute: 0));
  });
}
