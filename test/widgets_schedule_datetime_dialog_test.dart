import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/calendar/widgets_schedule_datetime_dialog.dart';
import 'package:life_pilot/event/service_event_public.dart';

void main() {
  test('combines a selected calendar date and time', () {
    final choice = ScheduleDateTimeChoice(
      date: DateTime(2026, 9, 15),
      time: const TimeOfDay(hour: 18, minute: 30),
    );

    expect(choice.dateTime, DateTime(2026, 9, 15, 18, 30));
  });

  test('dashboard dates are converted back to the device timezone', () {
    final parsed = DateTimeParser.parseDate('2026-09-14T16:00:00.000Z');

    expect(parsed, isNotNull);
    expect(parsed!.isUtc, isFalse);
    expect(parsed.toUtc(), DateTime.utc(2026, 9, 14, 16));
  });
}
