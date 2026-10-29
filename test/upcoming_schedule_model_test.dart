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
  test(
    'strictly ordered lists retain original results at every insertion point',
    () {
      final rows = List<CalendarEvent>.unmodifiable(
        List.generate(100, (i) => event('existing-$i', minute: i * 2 + 1)),
      );
      for (var minute = 0; minute <= 200; minute += 2) {
        final added = event('new', minute: minute);
        expect(
          ModelUpcomingSchedule.withEvent(events: rows, event: added, now: now),
          orderedEquals(legacy(rows, added)),
          reason: 'minute $minute',
        );
      }
      expect(rows.first.id, 'existing-0');
      expect(rows.last.id, 'existing-99');
    },
  );
  test(
    'ties in existing rows or the added row retain legacy sort behavior',
    () {
      for (final repeated in [true, false]) {
        final rows = List.generate(
          100,
          (i) => event('existing-$i', minute: repeated ? (i ~/ 3) * 2 : i * 2),
        );
        for (final minute in [0, 20, 51, 200]) {
          final added = event('new', minute: minute);
          expect(
            ModelUpcomingSchedule.withEvent(
              events: rows,
              event: added,
              now: now,
            ),
            orderedEquals(legacy(rows, added)),
            reason: 'repeated=$repeated minute=$minute',
          );
        }
      }
    },
  );
  test(
    'moving an existing ID within a sorted list preserves replacement rules',
    () {
      final rows = List.generate(80, (i) => event('$i', minute: i * 3));
      for (final minute in [0, 61, 400]) {
        final updated = event('40', minute: minute);
        final result = ModelUpcomingSchedule.withEvent(
          events: rows,
          event: updated,
          now: now,
        )!;
        expect(result, orderedEquals(legacy(rows, updated)));
        expect(result.where((e) => e.id == '40').single, same(updated));
        expect(rows[40].startTime, const TimeOfDay(hour: 2, minute: 0));
      }
    },
  );
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
    expect(added.dates, 1); // eligibility is also the sorting key
    expect(added.times, 1);
  });

  test(
    'undated existing rows are retained last instead of breaking insertion',
    () {
      final unknown = CalendarEvent(id: 'undated', name: 'Undated');
      final existing = event('existing', minute: 600);
      final added = event('new', minute: 700);
      final source = List<CalendarEvent>.unmodifiable([unknown, existing]);
      final result = ModelUpcomingSchedule.withEvent(
        events: source,
        event: added,
        now: now,
      )!;
      expect(result, [existing, added, unknown]);
      expect(source, [unknown, existing]);
      expect(result.last, same(unknown));
    },
  );

  test('undated existing copy of an updated ID is replaced normally', () {
    final old = CalendarEvent(id: 'same', name: 'Undated');
    final added = event('same');
    expect(
      ModelUpcomingSchedule.withEvent(events: [old], event: added, now: now),
      [added],
    );
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
