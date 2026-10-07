import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/event/event_item_schedule_comparator.dart';
import 'package:life_pilot/event/model_event_item.dart';

void main() {
  EventItem event({
    DateTime? startDate,
    TimeOfDay? startTime,
    DateTime? endDate,
    TimeOfDay? endTime,
  }) {
    return EventItem()
      ..startDate = startDate
      ..startTime = startTime
      ..endDate = endDate
      ..endTime = endTime;
  }

  test('sorts events by start date before other schedule fields', () {
    final earlier = event(startDate: DateTime(2026, 10, 7));
    final later = event(startDate: DateTime(2026, 10, 8));

    expect(EventItemScheduleComparator.compare(earlier, later), isNegative);
  });

  test('sorts same-day events by start time', () {
    final morning = event(
      startDate: DateTime(2026, 10, 7),
      startTime: const TimeOfDay(hour: 9, minute: 0),
    );
    final afternoon = event(
      startDate: DateTime(2026, 10, 7),
      startTime: const TimeOfDay(hour: 14, minute: 0),
    );

    expect(EventItemScheduleComparator.compare(morning, afternoon), isNegative);
  });

  test('uses end date and end time when starts match', () {
    final earlierEnd = event(
      startDate: DateTime(2026, 10, 7),
      startTime: const TimeOfDay(hour: 9, minute: 0),
      endDate: DateTime(2026, 10, 7),
      endTime: const TimeOfDay(hour: 10, minute: 0),
    );
    final laterEnd = event(
      startDate: DateTime(2026, 10, 7),
      startTime: const TimeOfDay(hour: 9, minute: 0),
      endDate: DateTime(2026, 10, 7),
      endTime: const TimeOfDay(hour: 11, minute: 0),
    );

    expect(
      EventItemScheduleComparator.compare(earlierEnd, laterEnd),
      isNegative,
    );
  });

  test('keeps missing dates after scheduled events', () {
    final scheduled = event(startDate: DateTime(2026, 10, 7));
    final undated = event();

    expect(EventItemScheduleComparator.compare(scheduled, undated), isNegative);
  });
}
