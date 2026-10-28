import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/calendar/model_calendar.dart';
import 'package:life_pilot/calendar/model_calendar_day_grouping.dart';
import 'package:life_pilot/event/model_event_item.dart';

class _Work {
  int comparisons = 0;
}

class _CellDate implements DateTime {
  final DateTime value;
  final _Work work;
  _CellDate(this.value, this.work);
  DateTime unwrap(DateTime other) => other is _CellDate ? other.value : other;
  @override
  int compareTo(DateTime other) {
    work.comparisons++;
    return value.compareTo(unwrap(other));
  }

  @override
  bool isBefore(DateTime other) {
    work.comparisons++;
    return value.isBefore(unwrap(other));
  }

  @override
  bool isAfter(DateTime other) {
    work.comparisons++;
    return value.isAfter(unwrap(other));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  for (final spanning in [false, true]) {
    test('$spanning repeating one range does not repeat grid comparisons', () {
      final weeks = ModelCalendar().getWeeks(DateTime(2026, 10));
      int run(int count) {
        final work = _Work();
        final grid = [
          for (final week in weeks)
            [for (final date in week) _CellDate(date, work)],
        ];
        final rows = [
          for (var i = 0; i < count; i++)
            EventItem(
              id: '$i',
              name: '$i',
              startDate: DateTime(2026, 10, 3, i % 24),
              endDate: spanning ? DateTime(2026, 11, 2) : null,
            ),
        ];
        final result = ModelCalendarDayGrouping.group(
          weeks: grid,
          events: rows,
        );
        final occupied = result.values
            .expand((week) => week.values)
            .where((day) => day.isNotEmpty);
        expect(occupied, isNotEmpty);
        for (final cell in occupied) {
          expect(cell, orderedEquals(rows));
        }
        return work.comparisons;
      }

      expect(run(1000), run(1));
    });
  }

  test('same start but changing end invalidates the range bounds', () {
    final weeks = ModelCalendar().getWeeks(DateTime(2026, 10));
    final rows = [
      for (final end in [2, 4, 1, 4, 2])
        EventItem(
          id: '$end',
          name: '$end',
          startDate: DateTime(2026, 10, 2),
          endDate: DateTime(2026, 10, end),
        ),
    ];
    final grouped = ModelCalendarDayGrouping.group(weeks: weeks, events: rows);
    for (var w = 0; w < weeks.length; w++) {
      for (var d = 0; d < 7; d++) {
        final date = weeks[w][d];
        expect(
          grouped[w]![d],
          rows.where(
            (e) => !date.isBefore(e.startDate!) && !date.isAfter(e.endDate!),
          ),
        );
      }
    }
  });

  test(
    'randomized reordered/duplicate grids and ranges match full projection',
    () {
      final random = Random(20261028);
      final model = ModelCalendar();
      for (var batch = 0; batch < 100; batch++) {
        final weeks = model
            .getWeeks(DateTime(2026, 10))
            .map((week) => List<DateTime>.of(week))
            .toList();
        if (batch.isEven) weeks.shuffle(random);
        if (batch % 3 == 0) weeks.add(List<DateTime>.of(weeks.first));
        final rows = [
          for (var i = 0; i < 50; i++)
            EventItem(
              id: '$i',
              name: '$i',
              startDate: DateTime(2026, 10, random.nextInt(60) - 10),
              endDate: random.nextBool()
                  ? null
                  : DateTime(2026, 10, random.nextInt(60) - 10),
            ),
        ];
        final grouped = ModelCalendarDayGrouping.group(
          weeks: weeks,
          events: rows,
        );
        for (var w = 0; w < weeks.length; w++) {
          for (var d = 0; d < 7; d++) {
            final date = weeks[w][d];
            expect(
              grouped[w]![d],
              rows.where(
                (event) =>
                    !date.isBefore(event.startDate!) &&
                    !date.isAfter(event.endDate ?? event.startDate!),
              ),
              reason: 'batch $batch, $w/$d',
            );
          }
        }
      }
    },
  );

  test('range reuse cannot survive a later projection with edited dates', () {
    final weeks = ModelCalendar().getWeeks(DateTime(2026, 10));
    final row = EventItem(
      id: 'edit',
      name: 'edit',
      startDate: DateTime(2026, 10, 2),
    );
    final first = ModelCalendarDayGrouping.group(weeks: weeks, events: [row]);
    row.startDate = DateTime(2026, 10, 9);
    final second = ModelCalendarDayGrouping.group(weeks: weeks, events: [row]);
    for (var w = 0; w < weeks.length; w++) {
      for (var d = 0; d < 7; d++) {
        expect(first[w]![d]!.isNotEmpty, weeks[w][d] == DateTime(2026, 10, 2));
        expect(second[w]![d]!.isNotEmpty, weeks[w][d] == DateTime(2026, 10, 9));
      }
    }
  });
}
