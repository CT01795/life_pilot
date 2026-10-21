import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/calendar/model_calendar.dart';
import 'package:life_pilot/calendar/model_calendar_week_layout.dart';
import 'package:life_pilot/event/model_event_item.dart';
import 'package:life_pilot/utils/date_time.dart';

void main() {
  final start = DateTime(2026, 10, 4);
  final end = DateTime(2026, 10, 10);
  EventWithRow place(DateTime first, DateTime? last) => ModelCalendarWeekLayout(
    [EventItem(id: 'a', name: 'A', startDate: first, endDate: last)],
  ).forWeek(start, end).single;

  test('single-day placement retains inclusive width and both round ends', () {
    final row = place(DateTime(2026, 10, 6, 19, 30), null);
    expect(row.visibleStart, DateTime(2026, 10, 6));
    expect(row.startIndex, 2);
    expect(row.spanDays, 1);
    expect(row.startsHere, true);
    expect(row.endsHere, true);
    expect(row.dateAtOffset(-100), DateTime(2026, 10, 6));
    expect(row.dateAtOffset(100), DateTime(2026, 10, 6));
  });

  test('a long event fills this week without marking either end as final', () {
    final row = place(DateTime(2026, 9), DateTime(2026, 11));
    expect(row.visibleStart, start);
    expect(row.startIndex, 0);
    expect(row.spanDays, 7);
    expect(row.startsHere, false);
    expect(row.endsHere, false);
    for (var offset = -3; offset <= 10; offset++) {
      expect(
        row.dateAtOffset(offset),
        start.add(Duration(days: offset.clamp(0, 6))),
      );
    }
  });

  test(
    'month-spanning event has independent clipping and tap dates per week',
    () {
      final event = EventItem(
        id: 'a',
        name: 'A',
        startDate: DateTime(2026, 9, 30),
        endDate: DateTime(2026, 10, 8),
      );
      final layout = ModelCalendarWeekLayout([event]);
      final previous = layout
          .forWeek(DateTime(2026, 9, 27), DateTime(2026, 10, 3))
          .single;
      final current = layout.forWeek(start, end).single;
      expect(
        (
          previous.startIndex,
          previous.spanDays,
          previous.startsHere,
          previous.endsHere,
        ),
        (3, 4, true, false),
      );
      expect(
        (
          current.startIndex,
          current.spanDays,
          current.startsHere,
          current.endsHere,
        ),
        (0, 5, false, true),
      );
      expect(previous.dateAtOffset(99), DateTime(2026, 10, 3));
      expect(current.dateAtOffset(0), DateTime(2026, 10, 4));
      expect(current.dateAtOffset(99), DateTime(2026, 10, 8));
      expect(event.startDate, DateTime(2026, 9, 30));
      expect(event.endDate, DateTime(2026, 10, 8));
    },
  );

  test('cross-year and leap-day placements retain the actual date', () {
    for (final day in [DateTime(2026, 12, 31), DateTime(2024, 2, 29)]) {
      final weekStart = day.subtract(const Duration(days: 2));
      final row = ModelCalendarWeekLayout([
        EventItem(id: 'a', name: 'A', startDate: day),
      ]).forWeek(weekStart, weekStart.add(const Duration(days: 6))).single;
      expect((row.startIndex, row.spanDays), (2, 1));
      expect(row.dateAtOffset(0), day);
    }
  });

  test(
    'cached placements match the previous view calculation in 100 batches',
    () {
      final random = Random(483);
      final calendar = ModelCalendar();
      for (var batch = 0; batch < 100; batch++) {
        final month = DateTime(2026, batch % 12 + 1);
        final events = List.generate(80, (i) {
          final date = month.add(
            Duration(days: random.nextInt(70) - 25, hours: random.nextInt(24)),
          );
          return EventItem(
            id: '$i',
            name: '$i',
            startDate: date,
            endDate: i % 3 == 0
                ? null
                : date.add(Duration(days: random.nextInt(40) - 3)),
          );
        });
        final layout = ModelCalendarWeekLayout(events);
        for (final week in calendar.getWeeks(month)) {
          for (final row in layout.forWeek(week.first, week.last)) {
            final first = DateTimeFormatter.dateOnly(row.event.startDate!);
            final last = DateTimeFormatter.dateOnly(
              row.event.endDate ?? row.event.startDate!,
            );
            final visibleFirst = first.isBefore(week.first)
                ? week.first
                : first;
            final visibleLast = last.isAfter(week.last) ? week.last : last;
            expect(row.visibleStart, visibleFirst);
            expect(row.startIndex, visibleFirst.difference(week.first).inDays);
            expect(
              row.spanDays,
              visibleLast.difference(visibleFirst).inDays + 1,
            );
            expect(row.startsHere, first.isAtSameMomentAs(visibleFirst));
            expect(row.endsHere, last.isAtSameMomentAs(visibleLast));
          }
        }
      }
    },
  );

  test(
    'edited and reloaded month replaces placement while old snapshot stays intact',
    () {
      final event = EventItem(
        id: 'a',
        name: 'A',
        startDate: DateTime(2026, 10, 6),
      );
      final model = ModelCalendar();
      model.cacheMonthEvents(start, [event]);
      final week = model
          .getWeeks(start)
          .indexWhere((dates) => dates.first == start);
      final old = model.eventRowsForWeek(start, week).single;
      expect(old.startIndex, 2);
      model.invalidateEventRange(startDate: event.startDate);
      event.startDate = DateTime(2026, 10, 8);
      model.cacheMonthEvents(start, [event]);
      final updated = model.eventRowsForWeek(start, week).single;
      expect(updated, isNot(same(old)));
      expect(updated.startIndex, 4);
      expect(updated.dateAtOffset(0), DateTime(2026, 10, 8));
      expect(old.startIndex, 2);
      expect(old.dateAtOffset(0), DateTime(2026, 10, 6));
    },
  );
}
