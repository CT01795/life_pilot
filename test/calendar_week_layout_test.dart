import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/calendar/model_calendar.dart';
import 'package:life_pilot/calendar/model_calendar_week_layout.dart';
import 'package:life_pilot/event/model_event_item.dart';
import 'package:life_pilot/utils/date_time.dart';

class _DateReadEvent extends EventItem {
  _DateReadEvent()
    : super(
        id: 'count',
        name: 'Count',
        startDate: DateTime(2026, 10, 1),
        endDate: DateTime(2026, 10, 3),
      );
  int reads = 0;
  @override
  DateTime? get startDate {
    reads++;
    return super.startDate;
  }
}

List<(String, int)> _reference(List<EventItem> events, List<DateTime> week) {
  final selected = events.where((event) {
    final start = DateTimeFormatter.dateOnly(event.startDate!);
    final end = DateTimeFormatter.dateOnly(event.endDate ?? event.startDate!);
    return !(end.isBefore(week.first) || start.isAfter(week.last));
  });
  final rows = <List<EventItem>>[];
  for (final event in selected) {
    final free = rows.indexWhere(
      (row) => !row.any((other) {
        final aStart = DateTimeFormatter.dateOnly(event.startDate!);
        final aEnd = DateTimeFormatter.dateOnly(
          event.endDate ?? event.startDate!,
        );
        final bStart = DateTimeFormatter.dateOnly(other.startDate!);
        final bEnd = DateTimeFormatter.dateOnly(
          other.endDate ?? other.startDate!,
        );
        return !(aEnd.isBefore(bStart) || aStart.isAfter(bEnd));
      }),
    );
    if (free < 0) {
      rows.add([event]);
    } else {
      rows[free].add(event);
    }
  }
  return [
    for (var i = 0; i < rows.length; i++)
      for (final e in rows[i]) (e.id, i),
  ];
}

void main() {
  test('ordered fast path matches original first-fit rows in 100 batches', () {
    final random = Random(53);
    final calendar = ModelCalendar();
    for (var batch = 0; batch < 100; batch++) {
      final month = DateTime(2026, batch % 12 + 1);
      final events = List.generate(120, (i) {
        final start = month.add(Duration(days: random.nextInt(50) - 10));
        return EventItem(
          id: '$i',
          name: '$i',
          startDate: start,
          endDate: random.nextBool()
              ? null
              : start.add(Duration(days: random.nextInt(15))),
        );
      })..sort((a, b) => a.startDate!.compareTo(b.startDate!));
      final layout = ModelCalendarWeekLayout(events);
      for (final week in calendar.getWeeks(month)) {
        expect(
          layout
              .forWeek(week.first, week.last)
              .map((e) => (e.event.id, e.rowIndex)),
          _reference(events, week),
          reason: 'batch $batch',
        );
      }
    }
  });
  test(
    'ordered placement reuses the first free row, not earliest ending row',
    () {
      final start = DateTime(2026, 10, 4);
      final week = List.generate(7, (i) => start.add(Duration(days: i)));
      final events = [
        EventItem(
          id: 'a',
          name: 'a',
          startDate: start,
          endDate: start.add(const Duration(days: 2)),
        ),
        EventItem(
          id: 'b',
          name: 'b',
          startDate: start,
          endDate: start.add(const Duration(days: 1)),
        ),
        EventItem(
          id: 'c',
          name: 'c',
          startDate: start.add(const Duration(days: 3)),
        ),
      ];
      final result = ModelCalendarWeekLayout(
        events,
      ).forWeek(week.first, week.last);
      expect(result.map((e) => (e.event.id, e.rowIndex)), [
        ('a', 0),
        ('c', 0),
        ('b', 1),
      ]);
    },
  );
  test('same-day touching ranges stay on separate rows', () {
    final start = DateTime(2026, 10, 4);
    final events = [
      EventItem(
        id: 'a',
        name: 'a',
        startDate: start,
        endDate: start.add(const Duration(days: 1)),
      ),
      EventItem(
        id: 'b',
        name: 'b',
        startDate: start.add(const Duration(days: 1)),
      ),
    ];
    final result = ModelCalendarWeekLayout(
      events,
    ).forWeek(start, start.add(const Duration(days: 6)));
    expect(result.map((e) => e.rowIndex), [0, 1]);
  });
  test('unordered inputs retain original row allocation and source order', () {
    final start = DateTime(2026, 10, 4);
    final week = List.generate(7, (i) => start.add(Duration(days: i)));
    final events = [
      EventItem(id: 'late', name: 'late', startDate: week[5]),
      EventItem(
        id: 'early',
        name: 'early',
        startDate: week[0],
        endDate: week[2],
      ),
      EventItem(
        id: 'middle',
        name: 'middle',
        startDate: week[1],
        endDate: week[4],
      ),
    ];
    expect(
      ModelCalendarWeekLayout(
        events,
      ).forWeek(week.first, week.last).map((e) => (e.event.id, e.rowIndex)),
      _reference(events, week),
    );
    expect(events.map((e) => e.id), ['late', 'early', 'middle']);
  });
  test('reversed ranges use the original comparison semantics', () {
    final start = DateTime(2026, 10, 4);
    final week = List.generate(7, (i) => start.add(Duration(days: i)));
    final events = [
      EventItem(id: 'a', name: 'a', startDate: week[0], endDate: week[2]),
      EventItem(
        id: 'reversed',
        name: 'reversed',
        startDate: week[3],
        endDate: week[1],
      ),
      EventItem(id: 'b', name: 'b', startDate: week[4]),
    ];
    expect(
      ModelCalendarWeekLayout(
        events,
      ).forWeek(week.first, week.last).map((e) => (e.event.id, e.rowIndex)),
      _reference(events, week),
    );
  });
  test('repeat and other-week layouts do not normalize event dates again', () {
    final event = _DateReadEvent();
    final layout = ModelCalendarWeekLayout([event]);
    final first = layout.forWeek(DateTime(2026, 9, 27), DateTime(2026, 10, 3));
    expect(
      identical(
        first,
        layout.forWeek(DateTime(2026, 9, 27), DateTime(2026, 10, 3)),
      ),
      true,
    );
    layout.forWeek(DateTime(2026, 10, 4), DateTime(2026, 10, 10));
    expect(event.reads, 1);
  });
  final month = DateTime(2026, 10);
  EventItem event(String name) => EventItem(
    id: name,
    name: name,
    startDate: month,
    endDate: DateTime(2026, 10, 3),
  );

  test(
    'weekly layout preserves original ordering and inclusive overlap rules',
    () {
      final random = Random(107);
      final model = ModelCalendar();
      for (var m = 1; m <= 12; m++) {
        final date = DateTime(2026, m);
        final events = List.generate(80, (i) {
          final start = date.add(
            Duration(days: random.nextInt(65) - 20, hours: random.nextInt(24)),
          );
          return EventItem(
            id: '$i',
            name: '$i',
            startDate: start,
            endDate: i % 3 == 0
                ? null
                : start.add(Duration(days: random.nextInt(23))),
          );
        });
        final layout = ModelCalendarWeekLayout(events);
        for (final week in model.getWeeks(date)) {
          expect(
            layout
                .forWeek(week.first, week.last)
                .map((row) => (row.event.id, row.rowIndex))
                .toList(),
            _reference(events, week),
            reason: '$m/${week.first}',
          );
        }
      }
    },
  );

  test('unchanged week reuses the same read-only row list', () {
    final model = ModelCalendar()..cacheMonthEvents(month, [event('one')]);
    final first = model.eventRowsForWeek(month, 0);
    expect(identical(first, model.eventRowsForWeek(month, 0)), true);
    expect(first.single.event.name, 'one');
    expect(() => first.clear(), throwsUnsupportedError);
  });

  test('reloading same month replaces row identity and event content', () {
    final model = ModelCalendar()..cacheMonthEvents(month, [event('one')]);
    final first = model.eventRowsForWeek(month, 0);
    model.cacheMonthEvents(month, [event('updated')]);
    final updated = model.eventRowsForWeek(month, 0);
    expect(identical(first, updated), false);
    expect(updated.single.event.name, 'updated');
  });

  test('cross-month invalidation clears adjacent weekly layout', () {
    final model = ModelCalendar();
    final spanning = EventItem(
      id: 'cross',
      name: 'Cross',
      startDate: DateTime(2026, 9, 30),
      endDate: DateTime(2026, 10, 2),
    );
    model.cacheMonthEvents(month, [spanning]);
    expect(model.eventRowsForWeek(month, 0), isNotEmpty);
    model.updateCachedEvent(event: spanning);
    expect(model.eventRowsForWeek(month, 0), isEmpty);
  });

  test('scope clear and invalid week indexes cannot retain old rows', () {
    final model = ModelCalendar()..cacheMonthEvents(month, [event('one')]);
    model.eventRowsForWeek(month, 0);
    expect(model.eventRowsForWeek(month, -1), isEmpty);
    expect(model.eventRowsForWeek(month, 999), isEmpty);
    model.clearAll();
    expect(model.eventRowsForWeek(month, 0), isEmpty);
  });

  test('replacing a legacy month snapshot is detected without stale rows', () {
    final model = ModelCalendar()..cacheMonthEvents(month, [event('one')]);
    model.eventRowsForWeek(month, 0);
    model.flatMonthEventsCache['2026-10'] = [event('replacement')];
    expect(model.eventRowsForWeek(month, 0).single.event.id, 'replacement');
  });
}
