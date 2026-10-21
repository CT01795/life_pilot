import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/calendar/model_calendar.dart';
import 'package:life_pilot/calendar/model_calendar_day_lookup.dart';
import 'package:life_pilot/event/model_event_item.dart';

EventItem _event(String id, DateTime date) =>
    EventItem(id: id, name: id, startDate: date);

void main() {
  late ModelCalendar model;
  setUp(() => model = ModelCalendar());
  test('own-month query ignores time of day', () {
    final event = _event('a', DateTime(2026, 10, 21));
    model.cacheMonthEvents(DateTime(2026, 10), [event]);
    expect(model.getEventsOfDay(DateTime(2026, 10, 21, 23, 59)), [event]);
  });
  test('month-start date uses the previous month grid indices', () {
    final event = _event('a', DateTime(2026, 10, 1));
    model.cacheMonthEvents(DateTime(2026, 9), [event]);
    expect(model.getEventsOfDay(DateTime(2026, 10, 1)), [event]);
  });
  test('month-end date uses the next month grid indices', () {
    final event = _event('a', DateTime(2026, 7, 31));
    model.cacheMonthEvents(DateTime(2026, 8), [event]);
    expect(model.getEventsOfDay(DateTime(2026, 7, 31)), [event]);
  });
  test('next cache outside the date cannot hide valid previous cache', () {
    final event = _event('a', DateTime(2026, 10, 1));
    model.cacheMonthEvents(DateTime(2026, 9), [event]);
    model.cacheMonthEvents(DateTime(2026, 11), []);
    expect(model.getEventsOfDay(DateTime(2026, 10, 1)), [event]);
  });
  test(
    'a neighbour cannot return an unrelated date from the same grid index',
    () {
      model.cacheMonthEvents(DateTime(2026, 11), [
        _event('unrelated', DateTime(2026, 11, 9)),
      ]);
      expect(model.getEventsOfDay(DateTime(2026, 10, 5)), isEmpty);
    },
  );
  test('known empty own-month date does not fall back to stale neighbour', () {
    final event = _event('old', DateTime(2026, 10, 1));
    model.cacheMonthEvents(DateTime(2026, 9), [event]);
    model.cacheMonthEvents(DateTime(2026, 10), []);
    expect(model.getEventsOfDay(DateTime(2026, 10, 1)), isEmpty);
  });
  test('empty cache placeholder still permits neighbour fallback', () {
    final event = _event('a', DateTime(2026, 10, 1));
    model.cachedEvents['2026-10'] = {};
    model.cacheMonthEvents(DateTime(2026, 9), [event]);
    expect(model.getEventsOfDay(DateTime(2026, 10, 1)), [event]);
  });
  test('cross-year and leap-day cells are resolved in their snapshot grid', () {
    final yearEnd = _event('year', DateTime(2026, 12, 31));
    model.cacheMonthEvents(DateTime(2027, 1), [yearEnd]);
    expect(model.getEventsOfDay(DateTime(2026, 12, 31)), [yearEnd]);
    final leapDay = _event('leap', DateTime(2024, 2, 29));
    model.cacheMonthEvents(DateTime(2024, 3), [leapDay]);
    expect(model.getEventsOfDay(DateTime(2024, 2, 29)), [leapDay]);
  });
  test(
    'range invalidation and clearing do not leave a stale lookup result',
    () {
      final date = DateTime(2026, 10, 1);
      model.cacheMonthEvents(DateTime(2026, 9), [_event('a', date)]);
      expect(model.getEventsOfDay(date), isNotEmpty);
      model.invalidateEventRange(startDate: date);
      expect(model.getEventsOfDay(date), isEmpty);
      model.cacheMonthEvents(DateTime(2026, 10), [_event('b', date)]);
      model.clearAll();
      expect(model.getEventsOfDay(date), isEmpty);
    },
  );
  test('lookup distinguishes outside grid from a known empty cell', () {
    final weeks = model.getWeeks(DateTime(2026, 10));
    expect(
      ModelCalendarDayLookup.find(
        date: DateTime(2026, 12, 1),
        weeks: weeks,
        eventsByWeek: {},
      ),
      isNull,
    );
    expect(
      ModelCalendarDayLookup.find(
        date: DateTime(2026, 10, 1),
        weeks: weeks,
        eventsByWeek: {},
      ),
      isEmpty,
    );
  });
  test('read-only grid and grouped data are not changed or copied', () {
    final date = DateTime(2026, 10, 1),
        event = _event('a', DateTime(2026, 10, 1));
    final events = List<EventItem>.unmodifiable([event]);
    final weeks = List<List<DateTime>>.unmodifiable([
      List<DateTime>.unmodifiable([date]),
    ]);
    final grouped = Map<int, Map<int, List<EventItem>>>.unmodifiable({
      0: Map<int, List<EventItem>>.unmodifiable({0: events}),
    });
    expect(
      ModelCalendarDayLookup.find(
        date: date,
        weeks: weeks,
        eventsByWeek: grouped,
      ),
      same(events),
    );
  });
}
