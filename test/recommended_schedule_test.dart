import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/calendar/widgets_schedule_datetime_dialog.dart';

void main() {
  final now = DateTime(2026, 10, 6, 15, 30);

  test('future recommendation keeps its source date and time', () {
    final date = initialRecommendedScheduleDate(
      sourceDate: DateTime(2026, 10, 11),
      currentDateTime: now,
    );
    final time = initialRecommendedScheduleTime(
      selectedDate: date,
      sourceTime: const TimeOfDay(hour: 10, minute: 0),
      currentDateTime: now,
    );

    expect(date, DateTime(2026, 10, 11));
    expect(time, const TimeOfDay(hour: 10, minute: 0));
  });

  test('started recommendation uses the current date and time', () {
    final date = initialRecommendedScheduleDate(
      sourceDate: DateTime(2026, 10, 5),
      currentDateTime: now,
    );
    final time = initialRecommendedScheduleTime(
      selectedDate: date,
      sourceTime: const TimeOfDay(hour: 10, minute: 0),
      currentDateTime: now,
    );

    expect(date, DateTime(2026, 10, 6));
    expect(time, const TimeOfDay(hour: 15, minute: 30));
  });

  test('today recommendation keeps a later source time', () {
    final date = initialRecommendedScheduleDate(
      sourceDate: DateTime(2026, 10, 6),
      currentDateTime: now,
    );
    final time = initialRecommendedScheduleTime(
      selectedDate: date,
      sourceTime: const TimeOfDay(hour: 18, minute: 0),
      currentDateTime: now,
    );

    expect(date, DateTime(2026, 10, 6));
    expect(time, const TimeOfDay(hour: 18, minute: 0));
  });
}
