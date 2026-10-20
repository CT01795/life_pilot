import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/event/model_event_item.dart';
import 'package:life_pilot/memory_trace/model_memory_timeline.dart';

EventItem _event(String id, DateTime? date, {String city = ''}) =>
    EventItem(id: id, name: id, startDate: date, city: city);

class _LightEvent implements EventBase {
  final DateTime? date;
  _LightEvent(this.date);
  @override
  DateTime? get startDate => date;
  @override
  String get city => ' Taipei ';
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('Unexpected heavy field: ${invocation.memberName}');
}

void main() {
  final day = DateTime(2026, 10, 20);
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
