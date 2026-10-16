import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/calendar/model_calendar.dart';
import 'package:life_pilot/event/model_event_item.dart';
import 'package:life_pilot/utils/date_time.dart';

class _CountingEvent extends EventItem {
  _CountingEvent()
    : super(
        id: 'count',
        name: 'Count',
        startDate: DateTime(2026, 10, 1),
        endDate: DateTime(2026, 10, 31),
      );
  int reads = 0;
  @override
  DateTime? get startDate {
    reads++;
    return super.startDate;
  }
}

void main() {
  test('normalizes each event start only once per month grid', () {
    final model = ModelCalendar();
    final event = _CountingEvent();
    final weeks = model.getWeeks(DateTime(2026, 10));
    final grouped = model.groupEventsByWeekAndDay(
      weeks: weeks,
      inEvents: [event],
    );
    expect(event.reads, 1);
    final matches = grouped.values
        .expand((week) => week.values)
        .where((day) => day.isNotEmpty)
        .length;
    expect(matches, 31);
  });

  test(
    'grouping matches original inclusive rules and preserves event order',
    () {
      final model = ModelCalendar();
      final random = Random(42);
      for (var month = 1; month <= 12; month++) {
        final base = DateTime(2026, month, 1);
        final weeks = model.getWeeks(base);
        final events = List.generate(120, (i) {
          final start = base.add(
            Duration(days: random.nextInt(70) - 20, hours: random.nextInt(24)),
          );
          return EventItem(
            id: '$i',
            name: '$i',
            startDate: start,
            endDate: i % 3 == 0
                ? null
                : start.add(Duration(days: random.nextInt(40) - 2)),
          );
        });
        final grouped = model.groupEventsByWeekAndDay(
          weeks: weeks,
          inEvents: events,
        );
        for (var w = 0; w < weeks.length; w++) {
          for (var d = 0; d < weeks[w].length; d++) {
            final day = weeks[w][d];
            final expected = events.where((event) {
              final start = DateTimeFormatter.dateOnly(event.startDate!);
              final end = DateTimeFormatter.dateOnly(event.endDate ?? start);
              return !day.isBefore(start) && !day.isAfter(end);
            }).toList();
            expect(grouped[w]![d], expected, reason: '$month / $w / $d');
          }
        }
      }
    },
  );

  test('empty month grid does not access event dates', () {
    final event = _CountingEvent();
    expect(
      ModelCalendar().groupEventsByWeekAndDay(weeks: [], inEvents: [event]),
      isEmpty,
    );
    expect(event.reads, 0);
  });
}
