import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/event/model_event_item.dart';
import 'package:life_pilot/memory_trace/model_memory_timeline.dart';

EventItem _event(String id, DateTime? date, {String city = ''}) =>
    EventItem(id: id, name: id, startDate: date, city: city);

class _LightEvent implements EventBase {
  final DateTime? date;
  int dateReads = 0;
  _LightEvent(this.date);
  @override
  DateTime? get startDate {
    dateReads++;
    return date;
  }

  @override
  String get city => ' Taipei ';
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('Unexpected heavy field: ${invocation.memberName}');
}

class _CountedDate implements DateTime {
  final DateTime value;
  int yearReads = 0;
  int monthReads = 0;
  int dayReads = 0;
  _CountedDate(this.value);
  @override
  int get year {
    yearReads++;
    return value.year;
  }

  @override
  int get month {
    monthReads++;
    return value.month;
  }

  @override
  int get day {
    dayReads++;
    return value.day;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('Unexpected date conversion: ${invocation.memberName}');
}

void main() {
  final day = DateTime(2026, 10, 20);
  test('one date decomposition supplies both day and month group keys', () {
    final date = _CountedDate(day);
    final event = _LightEvent(date);
    final model = ModelMemoryTimeline.fromEvents([event]);
    expect(event.dateReads, 1);
    expect([date.yearReads, date.monthReads, date.dayReads], [1, 1, 1]);
    expect(model.countForDay(day), 1);
    expect(model.countForMonth(day), 1);
    expect(model.headerAt(0)!.date, same(date));
  });

  test('unchanged display snapshot reuses its model and date projection', () {
    final date = _CountedDate(day);
    final rows = List<EventItem>.unmodifiable([_event('a', date)]);
    final first = ModelMemoryTimeline.forSnapshot(rows);
    expect(ModelMemoryTimeline.forSnapshot(rows), same(first));
    expect([date.yearReads, date.monthReads, date.dayReads], [1, 1, 1]);
  });

  test('replacement snapshot after editing rebuilds counts and headers', () {
    final event = _event('a', day, city: 'Taipei');
    final first = ModelMemoryTimeline.forSnapshot([event]);
    final next = DateTime(2027, 1, 2);
    event.startDate = next;
    event.city = '';
    final updated = ModelMemoryTimeline.forSnapshot([event]);
    expect(updated, isNot(same(first)));
    expect(updated.countForDay(day), 0);
    expect(updated.countForDay(next), 1);
    expect(updated.headerAt(0)!.date, next);
    expect(updated.cityCount, 0);
    expect(first.countForDay(day), 1);
    expect(first.headerAt(0)!.date, day);
    expect(first.cityCount, 1);
  });

  test('different snapshots with identical IDs never share a projection', () {
    final first = ModelMemoryTimeline.forSnapshot([_event('same', day)]);
    final second = ModelMemoryTimeline.forSnapshot([
      _event('same', DateTime(2025)),
    ]);
    expect(second, isNot(same(first)));
    expect(second.countForDay(day), 0);
    expect(first.countForDay(day), 1);
  });

  test('headers distinguish first, same day, next day and next month', () {
    final nextDay = DateTime(2026, 10, 21);
    final nextMonth = DateTime(2026, 11, 1);
    final model = ModelMemoryTimeline.fromEvents([
      _event('a', day),
      _event('b', day.add(const Duration(hours: 1))),
      _event('c', nextDay),
      _event('d', nextMonth),
    ]);
    expect(model.headerAt(0), (date: day, month: true, day: true));
    expect(model.headerAt(1), isNull);
    expect(model.headerAt(2), (date: nextDay, month: false, day: true));
    expect(model.headerAt(3), (date: nextMonth, month: true, day: true));
    expect(model.headerAt(-1), isNull);
    expect(model.headerAt(4), isNull);
  });
  test('undated rows reset adjacent header boundaries', () {
    final model = ModelMemoryTimeline.fromEvents([
      _event('a', day),
      _event('b', null),
      _event('c', day),
    ]);
    expect(model.headerAt(1), isNull);
    expect(model.headerAt(2), (date: day, month: true, day: true));
  });
  test('noncontiguous dates use adjacent rows rather than global counts', () {
    final other = DateTime(2026, 11, 1);
    final model = ModelMemoryTimeline.fromEvents([
      _event('a', day),
      _event('b', other),
      _event('c', day),
    ]);
    expect(model.headerAt(2), (date: day, month: true, day: true));
    expect(model.countForDay(day), 2);
  });
  test('equal month and day numbers in different years still have headers', () {
    final nextYear = DateTime(2027, 10, 20);
    final model = ModelMemoryTimeline.fromEvents([
      _event('a', day),
      _event('b', nextYear),
    ]);
    expect(model.headerAt(1), (date: nextYear, month: true, day: true));
  });
  test('edited dates get new headers without changing the previous model', () {
    final event = _event('a', day);
    final previous = ModelMemoryTimeline.fromEvents([event]);
    event.startDate = DateTime(2026, 11, 1);
    final updated = ModelMemoryTimeline.fromEvents([event]);
    expect(previous.headerAt(0)!.date, day);
    expect(updated.headerAt(0)!.date, event.startDate);
  });
  test('empty timeline returns zero rather than invented counts', () {
    final model = ModelMemoryTimeline.fromEvents([]);
    expect(model.memoryCount, 0);
    expect(model.dayCount, 0);
    expect(model.cityCount, 0);
    expect(model.countForDay(day), 0);
    expect(model.countForMonth(day), 0);
  });
  test('same day at different times counts once as a day', () {
    final model = ModelMemoryTimeline.fromEvents([
      _event('a', day),
      _event('b', day.add(const Duration(hours: 12))),
      _event('c', day.add(const Duration(days: 1))),
    ]);
    expect(model.memoryCount, 3);
    expect(model.dayCount, 2);
    expect(model.countForDay(day), 2);
    expect(model.countForMonth(day), 3);
  });
  test('year and month boundaries have independent keys', () {
    final model = ModelMemoryTimeline.fromEvents([
      _event('a', DateTime(2025, 10, 20)),
      _event('b', day),
      _event('c', DateTime(2026, 11, 20)),
    ]);
    expect(model.daily.length, 3);
    expect(model.monthly.length, 3);
    expect(model.countForMonth(DateTime(2025, 10)), 1);
  });
  test('undated records count as memories but not days or cities', () {
    final model = ModelMemoryTimeline.fromEvents([
      _event('a', null, city: 'Tokyo'),
      _event('b', day, city: 'Taipei'),
    ]);
    expect(model.memoryCount, 2);
    expect(model.dayCount, 1);
    expect(model.cityCount, 1);
  });
  test('city normalization preserves trim and case rules, ignoring blanks', () {
    final model = ModelMemoryTimeline.fromEvents([
      for (final city in [' Taipei ', 'taipei', 'Taipei', ' ', 'Tokyo'])
        _event(city, day, city: city),
    ]);
    expect(model.cityCount, 2);
  });
  test('published counters are immutable', () {
    final model = ModelMemoryTimeline.fromEvents([_event('a', day)]);
    expect(() => model.daily.clear(), throwsUnsupportedError);
    expect(() => model.monthly[202610] = 10, throwsUnsupportedError);
  });
  test('read-only input and event ordering remain untouched', () {
    final a = _event('a', day.add(const Duration(days: 1)));
    final b = _event('b', day);
    final rows = List<EventItem>.unmodifiable([a, b]);
    ModelMemoryTimeline.fromEvents(rows);
    expect(rows, [a, b]);
    expect(a.startDate, day.add(const Duration(days: 1)));
  });
  test('rebuilding after an edit does not retain old counts', () {
    final event = _event('a', day, city: 'Taipei');
    final previous = ModelMemoryTimeline.fromEvents([event]);
    event.startDate = day.add(const Duration(days: 1));
    final updated = ModelMemoryTimeline.fromEvents([event]);
    expect(previous.countForDay(day), 1);
    expect(updated.countForDay(day), 0);
    expect(updated.countForDay(event.startDate!), 1);
  });
  test('one-pass input never reads photos, descriptions or sub-events', () {
    var visits = 0;
    Iterable<EventBase> source() sync* {
      for (var i = 0; i < 5000; i++) {
        visits++;
        yield _LightEvent(day);
      }
    }

    final model = ModelMemoryTimeline.fromEvents(source());
    expect(visits, 5000);
    expect(model.memoryCount, 5000);
    expect(model.countForDay(day), 5000);
    expect(model.cityCount, 1);
  });
}
