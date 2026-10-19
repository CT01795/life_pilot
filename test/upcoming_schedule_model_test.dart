import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/pages/home/model/dashboard/model_upcoming_schedule.dart';
import 'package:life_pilot/pages/home/model/event/calendar_event.dart';

final now = DateTime(2026, 10, 19, 12);

CalendarEvent event(
  String id, {
  int day = 19,
  int? minute,
  bool completed = false,
}) => CalendarEvent(
  id: id,
  name: id,
  startDate: DateTime(2026, 10, day),
  startTime: minute == null
      ? null
      : TimeOfDay(hour: minute ~/ 60, minute: minute % 60),
  isCompleted: completed,
);

class _CountedEvent extends CalendarEvent {
  _CountedEvent(String id, int minute)
    : super(
        id: id,
        name: id,
        startDate: DateTime(2026, 10, 19),
        startTime: TimeOfDay(hour: minute ~/ 60, minute: minute % 60),
      );
  int dates = 0, times = 0;
  @override
  DateTime? get startDate {
    dates++;
    return super.startDate;
  }

  @override
  TimeOfDay? get startTime {
    times++;
    return super.startTime;
  }
}

List<CalendarEvent> legacy(List<CalendarEvent> source, CalendarEvent added) =>
    [...source.where((row) => row.id != added.id), added]..sort((a, b) {
      final date = a.startDate!.compareTo(b.startDate!);
      if (date != 0) return date;
      final am = (a.startTime?.hour ?? 0) * 60 + (a.startTime?.minute ?? 0);
      final bm = (b.startTime?.hour ?? 0) * 60 + (b.startTime?.minute ?? 0);
      return am.compareTo(bm);
    });

void main() {
  for (final day in [19, 20, 21]) {
    test('day $day remains inside the three-day dashboard window', () {
      final added = event('new', day: day);
      expect(
        ModelUpcomingSchedule.withEvent(events: [], event: added, now: now),
        [added],
      );
    });
  }

  test('past outside-window missing-date and completed events are ignored', () {
    for (final row in [
      event('past', day: 18),
      event('future', day: 22),
      event('done', completed: true),
      CalendarEvent(id: 'missing', name: ''),
    ]) {
      expect(
        ModelUpcomingSchedule.withEvent(events: [], event: row, now: now),
        isNull,
      );
    }
  });

  test('eligible update replaces all existing copies of its ID', () {
    final keep = event('keep', minute: 600);
    final update = event('same', minute: 800);
    final result = ModelUpcomingSchedule.withEvent(
      events: [event('same'), keep, event('same')],
      event: update,
      now: now,
    )!;
    expect(result, [keep, update]);
    expect(identical(result.last, update), isTrue);
  });

  test('dates sort before clock times and untimed entries remain midnight', () {
    final rows = [
      event('tomorrow', day: 20),
      event('late', minute: 800),
      event('early', minute: 600),
    ];
    final result = ModelUpcomingSchedule.withEvent(
      events: rows,
      event: event('untimed'),
      now: now,
    )!;
    expect(result.map((e) => e.id), ['untimed', 'early', 'late', 'tomorrow']);
  });

  test('full start timestamp is retained as the primary sorting key', () {
    final laterDate = CalendarEvent(
      id: 'timestamp',
      name: '',
      startDate: DateTime(2026, 10, 19, 12),
      startTime: const TimeOfDay(hour: 1, minute: 0),
    );
    final added = event('midnight-date', minute: 1300);
    expect(
      ModelUpcomingSchedule.withEvent(
        events: [laterDate],
        event: added,
        now: now,
      ),
      [added, laterDate],
    );
  });

  test('input order and membership are never mutated', () {
    final rows = [event('late', minute: 800), event('early', minute: 600)];
    final before = List<CalendarEvent>.of(rows);
    final result = ModelUpcomingSchedule.withEvent(
      events: rows,
      event: event('new'),
      now: now,
    )!;
    expect(rows, orderedEquals(before));
    expect(identical(rows, result), isFalse);
    expect(() => result.add(event('extra')), throwsUnsupportedError);
  });

  test('ineligible update does not remove a previously visible ID', () {
    final source = [event('same')];
    expect(
      ModelUpcomingSchedule.withEvent(
        events: source,
        event: event('same', day: 25),
        now: now,
      ),
      isNull,
    );
    expect(source.single.startDate, DateTime(2026, 10, 19));
  });

  test('sort keys read each existing event date and clock once', () {
    final rows = List.generate(100, (i) => _CountedEvent('$i', 1000 - i));
    final added = _CountedEvent('new', 30);
    ModelUpcomingSchedule.withEvent(events: rows, event: added, now: now);
    expect(rows.every((row) => row.dates == 1 && row.times == 1), isTrue);
    expect(added.dates, 2); // eligibility and one sorting key
    expect(added.times, 1);
  });

  test(
    'ordering and duplicate replacement match previous generated results',
    () {
      final random = Random(2210);
      for (var i = 0; i < 300; i++) {
        final rows = List.generate(
          random.nextInt(100),
          (j) => event(
            '${random.nextInt(40)}',
            day: 19 + random.nextInt(3),
            minute: random.nextBool() ? null : random.nextInt(24) * 60,
          ),
        );
        final added = event(
          '${random.nextInt(40)}',
          day: 19 + random.nextInt(3),
          minute: random.nextInt(24) * 60,
        );
        expect(
          ModelUpcomingSchedule.withEvent(events: rows, event: added, now: now),
          orderedEquals(legacy(rows, added)),
          reason: 'batch $i',
        );
      }
    },
  );
}
