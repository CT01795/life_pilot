import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/calendar/model_calendar.dart';
import 'package:life_pilot/calendar/model_calendar_day_grouping.dart';
import 'package:life_pilot/event/model_event_item.dart';
import 'package:life_pilot/utils/date_time.dart';

class _Comparisons {
  int count = 0;
}

class _ObservedDate implements DateTime {
  final DateTime date;
  final _Comparisons comparisons;
  _ObservedDate(this.date, this.comparisons);
  DateTime _unwrap(DateTime other) =>
      other is _ObservedDate ? other.date : other;
  @override
  bool isBefore(DateTime other) {
    comparisons.count++;
    return date.isBefore(_unwrap(other));
  }

  @override
  bool isAfter(DateTime other) {
    comparisons.count++;
    return date.isAfter(_unwrap(other));
  }

  @override
  int compareTo(DateTime other) {
    comparisons.count++;
    return date.compareTo(_unwrap(other));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('$invocation');
}

EventItem event(String id, DateTime start, [DateTime? end]) =>
    EventItem(id: id, name: id, startDate: start, endDate: end);

void main() {
  final model = ModelCalendar();
  final month = DateTime(2026, 10);
  final weeks = model.getWeeks(month);

  test('empty input still initializes every day cell', () {
    final result = ModelCalendarDayGrouping.group(weeks: weeks, events: []);
    expect(result.length, weeks.length);
    for (final week in result.values) {
      expect(week.keys, orderedEquals(List.generate(7, (i) => i)));
      expect(week.values.every((day) => day.isEmpty), isTrue);
    }
  });

  test('long spans are clipped to the visible grid only', () {
    final spanning = event('span', DateTime(2025), DateTime(2028));
    final result = ModelCalendarDayGrouping.group(
      weeks: weeks,
      events: [
        event('old', DateTime(2025)),
        spanning,
        event('future', DateTime(2028)),
      ],
    );
    for (final week in result.values) {
      for (final day in week.values) {
        expect(day, [spanning]);
      }
    }
  });

  test('single day ignores clock time and includes both date boundaries', () {
    final row = event('one', DateTime(2026, 10, 2, 23, 59));
    final result = ModelCalendarDayGrouping.group(weeks: weeks, events: [row]);
    final occupied = result.values
        .expand((week) => week.values)
        .where((day) => day.isNotEmpty);
    expect(occupied.single, [row]);
  });

  test('previous and next month padding dates are included', () {
    final first = event('first', weeks.first.first);
    final last = event('last', weeks.last.last);
    final result = ModelCalendarDayGrouping.group(
      weeks: weeks,
      events: [first, last],
    );
    expect(result[0]![0], [first]);
    expect(result[weeks.length - 1]![6], [last]);
  });

  test('reversed event range occupies no dates', () {
    final result = ModelCalendarDayGrouping.group(
      weeks: weeks,
      events: [event('reversed', DateTime(2026, 10, 3), DateTime(2026, 10, 1))],
    );
    expect(
      result.values.expand((week) => week.values).every((day) => day.isEmpty),
      isTrue,
    );
  });

  test('same-day source order and duplicate IDs remain unchanged', () {
    final rows = [
      event('b', weeks.first.first),
      event('a', weeks.first.first),
      event('a', weeks.first.first),
    ];
    final result = ModelCalendarDayGrouping.group(weeks: weeks, events: rows);
    expect(result[0]![0], orderedEquals(rows));
    expect(identical(result[0]![0]![2], rows[2]), isTrue);
  });

  test('reordered and repeated grid dates keep original cell coordinates', () {
    final days = List<DateTime>.of(weeks.first.reversed);
    final grid = [days, List<DateTime>.of(days)];
    final row = event('e', days[2]);
    final result = ModelCalendarDayGrouping.group(weeks: grid, events: [row]);
    expect(result[0]![2], [row]);
    expect(result[1]![2], [row]);
    expect(grid.first, orderedEquals(days));
  });

  test('leap day is included without extending into March', () {
    final grid = model.getWeeks(DateTime(2024, 2));
    final row = event('leap', DateTime(2024, 2, 28), DateTime(2024, 2, 29));
    final result = ModelCalendarDayGrouping.group(weeks: grid, events: [row]);
    expect(
      result.values
          .expand((week) => week.values)
          .where((day) => day.isNotEmpty)
          .length,
      2,
    );
  });

  test('mixed UTC grid values preserve the previous instant comparisons', () {
    final grid = [List.generate(7, (i) => DateTime.utc(2026, 10, i + 1, i))];
    final rows = [
      event('a', DateTime(2026, 10, 2), DateTime(2026, 10, 4)),
      event('b', DateTime.utc(2026, 10, 3)),
    ];
    final result = ModelCalendarDayGrouping.group(weeks: grid, events: rows);
    for (var i = 0; i < 7; i++) {
      expect(
        result[0]![i],
        rows.where((row) {
          final start = DateTimeFormatter.dateOnly(row.startDate!);
          final end = DateTimeFormatter.dateOnly(row.endDate ?? start);
          return !grid[0][i].isBefore(start) && !grid[0][i].isAfter(end);
        }),
      );
    }
  });

  test('month cache is regenerated after edited dates', () {
    final calendar = ModelCalendar();
    final row = event('e', DateTime(2026, 10, 1));
    calendar.cacheMonthEvents(month, [row]);
    expect(calendar.getEventsOfDay(DateTime(2026, 10, 1)), [row]);
    row.startDate = DateTime(2026, 10, 2);
    calendar.cacheMonthEvents(month, [row]);
    expect(calendar.getEventsOfDay(DateTime(2026, 10, 1)), isEmpty);
    expect(calendar.getEventsOfDay(DateTime(2026, 10, 2)), [row]);
  });

  test('single-day workloads do not scan every event for every grid date', () {
    final comparisons = _Comparisons();
    final grid = [
      for (final week in weeks)
        [for (final day in week) _ObservedDate(day, comparisons)],
    ];
    final rows = List.generate(
      2000,
      (i) => event('$i', DateTime(2026, 10, i % 28 + 1)),
    );
    final result = ModelCalendarDayGrouping.group(weeks: grid, events: rows);
    expect(
      result.values
          .expand((week) => week.values)
          .fold<int>(0, (sum, day) => sum + day.length),
      rows.length,
    );
    expect(comparisons.count, lessThan(rows.length * 12 + 500));
  });
}
