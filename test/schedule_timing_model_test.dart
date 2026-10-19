import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/pages/home/model/dashboard/model_schedule_timing.dart';
import 'package:life_pilot/pages/home/model/event/calendar_event.dart';

final date = DateTime(2026, 10, 19);

CalendarEvent event({DateTime? start, DateTime? end, bool endClock = true}) {
  start ??= DateTime(2026, 10, 19, 9);
  return CalendarEvent(
    id: 'e',
    name: 'e',
    startDate: start,
    startTime: TimeOfDay.fromDateTime(start),
    endDate: end,
    endTime: endClock && end != null ? TimeOfDay.fromDateTime(end) : null,
  );
}

({ScheduleTimingKind kind, int amount})? legacy(
  CalendarEvent event,
  DateTime now,
) {
  final day = event.startDate;
  final time = event.startTime;
  if (day == null || time == null) return null;
  final start = DateTime(day.year, day.month, day.day, time.hour, time.minute);
  final minutes = start.difference(now).inMinutes;
  if (minutes < 0) {
    final endDay = event.endDate ?? day;
    final endClock = event.endTime;
    final end = endClock != null
        ? DateTime(
            endDay.year,
            endDay.month,
            endDay.day,
            endClock.hour,
            endClock.minute,
          )
        : start.add(const Duration(hours: 1));
    return (
      kind: !end.isAfter(now)
          ? ScheduleTimingKind.needsReview
          : ScheduleTimingKind.alreadyStarted,
      amount: 0,
    );
  }
  if (minutes < 60) {
    return (kind: ScheduleTimingKind.minutes, amount: minutes + 1);
  }
  if (minutes < 1440) {
    return (kind: ScheduleTimingKind.hours, amount: (minutes / 60).ceil());
  }
  return null;
}

void main() {
  test('missing date or start clock has no timing hint', () {
    expect(
      ModelScheduleTiming.forEvent(CalendarEvent(id: 'a', name: ''), date),
      isNull,
    );
    expect(
      ModelScheduleTiming.forEvent(
        CalendarEvent(id: 'b', name: '', startDate: date),
        date,
      ),
      isNull,
    );
  });

  test('exact start retains one-minute countdown wording', () {
    final timing = ModelScheduleTiming.forEvent(
      event(),
      DateTime(2026, 10, 19, 9),
    )!;
    expect(timing.kind, ScheduleTimingKind.minutes);
    expect(timing.amount, 1);
  });

  test('sub-minute offsets preserve whole-minute rounding', () {
    for (final now in [
      DateTime(2026, 10, 19, 8, 59, 30),
      DateTime(2026, 10, 19, 9, 0, 30),
    ]) {
      final timing = ModelScheduleTiming.forEvent(event(), now)!;
      expect(timing.kind, ScheduleTimingKind.minutes);
      expect(timing.amount, 1);
    }
  });

  test('minute countdown includes its existing rounding increment', () {
    final timing = ModelScheduleTiming.forEvent(
      event(),
      DateTime(2026, 10, 19, 8, 1),
    )!;
    expect(timing.kind, ScheduleTimingKind.minutes);
    expect(timing.amount, 60);
  });

  test('one hour switches from minutes to hours', () {
    final timing = ModelScheduleTiming.forEvent(
      event(),
      DateTime(2026, 10, 19, 8),
    )!;
    expect(timing.kind, ScheduleTimingKind.hours);
    expect(timing.amount, 1);
  });

  test('sixty-one minutes rounds up to two hours', () {
    final timing = ModelScheduleTiming.forEvent(
      event(),
      DateTime(2026, 10, 19, 7, 59),
    )!;
    expect(timing.kind, ScheduleTimingKind.hours);
    expect(timing.amount, 2);
  });

  test('a start at least twenty-four hours away has no timing hint', () {
    expect(
      ModelScheduleTiming.forEvent(event(), DateTime(2026, 10, 18, 9)),
      isNull,
    );
  });

  test('started event with future end is marked already started', () {
    final timing = ModelScheduleTiming.forEvent(
      event(end: DateTime(2026, 10, 19, 12)),
      DateTime(2026, 10, 19, 10),
    )!;
    expect(timing.kind, ScheduleTimingKind.alreadyStarted);
  });

  test('end exactly at current time needs review', () {
    final timing = ModelScheduleTiming.forEvent(
      event(end: DateTime(2026, 10, 19, 10)),
      DateTime(2026, 10, 19, 10),
    )!;
    expect(timing.kind, ScheduleTimingKind.needsReview);
  });

  test(
    'missing end time preserves one-hour fallback even with an end date',
    () {
      final row = event(end: DateTime(2026, 10, 20), endClock: false);
      expect(
        ModelScheduleTiming.forEvent(row, DateTime(2026, 10, 19, 9, 30))!.kind,
        ScheduleTimingKind.alreadyStarted,
      );
      expect(
        ModelScheduleTiming.forEvent(row, DateTime(2026, 10, 19, 10))!.kind,
        ScheduleTimingKind.needsReview,
      );
    },
  );

  test('explicit cross-day end time remains active until that end', () {
    final row = event(end: DateTime(2026, 10, 20, 1));
    expect(
      ModelScheduleTiming.forEvent(row, DateTime(2026, 10, 19, 23))!.kind,
      ScheduleTimingKind.alreadyStarted,
    );
    expect(
      ModelScheduleTiming.forEvent(row, DateTime(2026, 10, 20, 1))!.kind,
      ScheduleTimingKind.needsReview,
    );
  });

  test('time classification matches original rules for generated cases', () {
    final random = Random(2110);
    for (var i = 0; i < 2000; i++) {
      final start = date.add(
        Duration(days: random.nextInt(5) - 2, minutes: random.nextInt(1440)),
      );
      final row = event(
        start: start,
        end: random.nextBool()
            ? start.add(Duration(minutes: random.nextInt(4000) - 30))
            : null,
        endClock: random.nextBool(),
      );
      final now = date.add(
        Duration(hours: random.nextInt(48), seconds: random.nextInt(3600)),
      );
      final actual = ModelScheduleTiming.forEvent(row, now);
      final expected = legacy(row, now);
      expect(actual?.kind, expected?.kind, reason: 'case $i');
      expect(actual?.amount, expected?.amount, reason: 'case $i');
    }
  });
}
