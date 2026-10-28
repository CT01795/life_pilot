import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/event/model_event_item.dart';
import 'package:life_pilot/memory_trace/model_memory_timeline.dart';

EventItem memory(String id, DateTime? date, {String city = 'Taipei'}) =>
    EventItem(id: id, name: id, startDate: date, city: city);

void main() {
  test('large same-day run is counted with its final pending run flushed', () {
    final date = DateTime(2026, 10, 28);
    final rows = [
      for (var i = 0; i < 5000; i++)
        memory('$i', date.add(Duration(minutes: i % 1440))),
    ];
    final model = ModelMemoryTimeline.fromEvents(rows);
    expect(model.memoryCount, 5000);
    expect(model.countForDay(date), 5000);
    expect(model.countForMonth(date), 5000);
    expect(model.dayCount, 1);
    expect(model.headerAt(0), (date: date, month: true, day: true));
    expect(model.headerAt(4999), isNull);
  });

  test(
    'undated rows retain their header reset without losing pending counts',
    () {
      final date = DateTime(2026, 10, 28);
      final model = ModelMemoryTimeline.fromEvents([
        memory('a', date),
        memory('none', null, city: 'ignored'),
        memory('b', date),
      ]);
      expect(model.memoryCount, 3);
      expect(model.countForDay(date), 2);
      expect(model.cityCount, 1);
      expect(model.headerAt(1), isNull);
      expect(model.headerAt(2), (date: date, month: true, day: true));
    },
  );

  test(
    'repeated non-adjacent dates add to existing totals in insertion order',
    () {
      final first = DateTime(2026, 10, 28), second = DateTime(2026, 11, 1);
      final rows = [first, first, second, first, second, second];
      final model = ModelMemoryTimeline.fromEvents([
        for (var i = 0; i < rows.length; i++) memory('$i', rows[i]),
      ]);
      expect(model.daily.keys, [20261028, 20261101]);
      expect(model.daily.values, [3, 3]);
      expect(model.monthly.keys, [202610, 202611]);
      expect(model.monthly.values, [3, 3]);
    },
  );

  test(
    'random unsorted dates, missing dates, cities and headers match original projection',
    () {
      final random = Random(20261028);
      for (var batch = 0; batch < 100; batch++) {
        final rows = [
          for (var i = 0; i < 100; i++)
            memory(
              '$i',
              random.nextInt(5) == 0
                  ? null
                  : DateTime(
                      2025 + random.nextInt(3),
                      1 + random.nextInt(12),
                      1 + random.nextInt(28),
                      random.nextInt(24),
                    ),
              city: ['Taipei', ' taipei ', 'Tokyo', ''][random.nextInt(4)],
            ),
        ];
        final daily = <int, int>{}, monthly = <int, int>{};
        final headers = <int, MemoryTimelineHeader>{};
        final cities = <String>{};
        int? previousDay, previousMonth;
        for (var i = 0; i < rows.length; i++) {
          final row = rows[i], date = row.startDate;
          if (date == null) {
            previousDay = null;
            previousMonth = null;
            continue;
          }
          final month = date.year * 100 + date.month,
              day = month * 100 + date.day;
          if (previousDay != day) {
            headers[i] = (date: date, month: previousMonth != month, day: true);
          }
          previousDay = day;
          previousMonth = month;
          daily[day] = (daily[day] ?? 0) + 1;
          monthly[month] = (monthly[month] ?? 0) + 1;
          final city = row.city.trim().toLowerCase();
          if (city.isNotEmpty) cities.add(city);
        }
        final model = ModelMemoryTimeline.fromEvents(rows);
        expect(model.daily, daily, reason: 'batch $batch');
        expect(model.daily.keys, daily.keys);
        expect(model.monthly, monthly);
        expect(model.monthly.keys, monthly.keys);
        expect(model.cityCount, cities.length);
        expect(model.memoryCount, rows.length);
        for (var i = 0; i < rows.length; i++) {
          expect(model.headerAt(i), headers[i]);
        }
      }
    },
  );

  test('empty and all-undated input never invent a pending date', () {
    for (final rows in [
      <EventItem>[],
      [memory('none', null)],
    ]) {
      final model = ModelMemoryTimeline.fromEvents(rows);
      expect(model.daily, isEmpty);
      expect(model.monthly, isEmpty);
      expect(model.memoryCount, rows.length);
    }
  });
}
