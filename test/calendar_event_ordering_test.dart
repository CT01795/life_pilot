import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/calendar/model_calendar.dart';
import 'package:life_pilot/event/model_event_item.dart';

EventItem _event(
  String id, {
  DateTime? date,
  TimeOfDay? time,
  String city = '',
  String location = '',
  String? name,
}) => EventItem(
  id: id,
  name: name ?? id,
  startDate: date,
  startTime: time,
  city: city,
  location: location,
);

class _CountedEvent extends EventItem {
  _CountedEvent(String id)
    : super(id: id, name: id, startDate: DateTime(2026, 10, 21));
  int dateReads = 0, timeReads = 0;
  @override
  DateTime? get startDate {
    dateReads++;
    return super.startDate;
  }

  @override
  TimeOfDay? get startTime {
    timeReads++;
    return super.startTime;
  }

  @override
  String get description =>
      throw StateError('Sorting must not read descriptions');
  @override
  String? get masterGraphUrl =>
      throw StateError('Sorting must not read photos');
  @override
  List<EventItem> get subEvents =>
      throw StateError('Sorting must not decode child events');
}

int _legacy(EventItem left, EventItem right) {
  var result = (left.startDate ?? DateTime(9999)).compareTo(
    right.startDate ?? DateTime(9999),
  );
  if (result != 0) return result;
  int minutes(TimeOfDay? time) =>
      time == null ? 1440 : time.hour * 60 + time.minute;
  result = minutes(left.startTime).compareTo(minutes(right.startTime));
  if (result != 0) return result;
  result = left.city.compareTo(right.city);
  if (result != 0) return result;
  result = left.location.compareTo(right.location);
  return result != 0 ? result : left.name.compareTo(right.name);
}

void main() {
  final day = DateTime(2026, 10, 21);
  List<String> ids(Iterable<EventItem> rows) =>
      ModelCalendar.orderedEvents(rows).map((e) => e.id).toList();
  test(
    'matches previous ordering including equal keys in 100 random batches',
    () {
      final random = Random(91);
      for (var batch = 0; batch < 100; batch++) {
        final rows = List.generate(
          120,
          (i) => _event(
            '$i',
            date: random.nextInt(4) == 0
                ? null
                : day.add(Duration(days: random.nextInt(4))),
            time: random.nextBool()
                ? null
                : TimeOfDay(hour: random.nextInt(3), minute: 0),
            city: '${random.nextInt(2)}',
            location: '${random.nextInt(2)}',
            name: '${random.nextInt(2)}',
          ),
        );
        final expected = List<EventItem>.of(rows)..sort(_legacy);
        expect(ids(rows), expected.map((e) => e.id), reason: 'batch $batch');
      }
    },
  );
  test('missing date sorts after dated entries', () {
    expect(ids([_event('none'), _event('dated', date: day)]), [
      'dated',
      'none',
    ]);
  });
  test('missing time sorts after 23:59 on the same date', () {
    expect(
      ids([
        _event('none', date: day),
        _event('late', date: day, time: const TimeOfDay(hour: 23, minute: 59)),
      ]),
      ['late', 'none'],
    );
  });
  test('city then location then name break equal schedule keys', () {
    expect(
      ids([
        _event('city', date: day, city: 'B'),
        _event('location', date: day, location: 'B'),
        _event('b', date: day, name: 'B'),
        _event('a', date: day, name: 'A'),
      ]),
      ['a', 'b', 'location', 'city'],
    );
  });
  test('read-only source is unchanged and object identities are retained', () {
    final a = _event('a', date: day),
        b = _event('b', date: day.subtract(const Duration(days: 1)));
    final rows = List<EventItem>.unmodifiable([a, b]);
    final ordered = ModelCalendar.orderedEvents(rows);
    expect(rows, [a, b]);
    expect(ordered, [b, a]);
    expect(ordered.first, same(b));
  });
  test('empty and single-entry sources return independent lists', () {
    expect(ids([]), isEmpty);
    final rows = [_event('a')];
    final ordered = ModelCalendar.orderedEvents(rows);
    expect(identical(rows, ordered), false);
    expect(ordered.single, same(rows.single));
  });
  test('one-shot source is iterated once', () {
    var visits = 0;
    Iterable<EventItem> rows() sync* {
      visits++;
      yield _event('b', date: day);
      visits++;
      yield _event('a', date: day);
    }

    expect(ids(rows()), ['a', 'b']);
    expect(visits, 2);
  });
  test(
    'keys are rebuilt after an event edit rather than cached across calls',
    () {
      final a = _event('a', date: day),
          b = _event('b', date: day.add(const Duration(days: 1)));
      expect(ids([a, b]), ['a', 'b']);
      a.startDate = day.add(const Duration(days: 2));
      expect(ids([a, b]), ['b', 'a']);
    },
  );
  test(
    'each date/time is read once without touching photos or child details',
    () {
      final rows = List.generate(1000, (i) => _CountedEvent('$i'));
      final ordered = ModelCalendar.orderedEvents(rows);
      expect(ordered.length, 1000);
      expect(rows.every((e) => e.dateReads == 1 && e.timeReads == 1), true);
    },
  );
}
