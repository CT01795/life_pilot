import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/event/model_event_ordering.dart';
import 'package:life_pilot/event/model_event.dart';
import 'package:life_pilot/event/model_event_item.dart';
import 'package:life_pilot/l10n/app_localizations_en.dart';
import 'package:life_pilot/utils/date_time.dart';

final today = DateTime(2026, 10, 15);
EventItem event(
  String id, {
  DateTime? date,
  DateTime? end,
  TimeOfDay? time,
  String city = '',
  String location = '',
  String? name,
  String country = 'TW',
  bool? like,
  bool? dislike,
}) => EventItem(
  id: id,
  name: name ?? id,
  startDate: date,
  endDate: end,
  startTime: time,
  city: city,
  location: location,
  country: country,
  isLike: like,
  isDislike: dislike,
);
List<String> ids(List<EventItem> events) =>
    events.map((event) => event.id).toList();

void main() {
  for (final mode in ['events', 'places', 'memory']) {
    test('$mode matches original ordering for 100 generated batches', () {
      final random = Random(84);
      for (var sample = 0; sample < 100; sample++) {
        final events = List.generate(
          40,
          (i) => event(
            '$i',
            date: random.nextInt(5) == 0
                ? null
                : today.add(Duration(days: random.nextInt(15) - 7)),
            end: random.nextBool()
                ? null
                : today.add(Duration(days: random.nextInt(15) - 7)),
            time: random.nextInt(4) == 0
                ? null
                : TimeOfDay(
                    hour: random.nextInt(24),
                    minute: random.nextInt(60),
                  ),
            country: random.nextBool() ? 'TW' : 'SG',
            city: 'City ${random.nextInt(4)}',
            location: 'Hall ${random.nextInt(4)}',
            like: random.nextInt(3) == 0,
            dislike: random.nextInt(3) == 0,
          ),
        )..shuffle(random);
        final expected = List<EventItem>.of(events);
        final legacy = _LegacyOrdering(expected, today);
        if (mode == 'memory') {
          ModelEventOrdering.sortMemory(events);
          legacy.sortMemoryEvents();
        } else {
          ModelEventOrdering.sortRecommended(
            events,
            isEvent: mode == 'events',
            now: today,
          );
          legacy.sortRecommendedContent(isEvent: mode == 'events');
        }
        expect(ids(events), ids(expected), reason: 'sample $sample');
      }
    });
  }
  test('preference wins over all date and place fields', () {
    final rows = [
      event('hate', date: today, dislike: true),
      event('normal', date: today),
      event('like', date: today.add(const Duration(days: 100)), like: true),
    ];
    ModelEventOrdering.sortRecommended(rows, isEvent: true, now: today);
    expect(ids(rows), ['like', 'normal', 'hate']);
  });
  test('like takes priority when both preference flags are true', () {
    final rows = [event('neutral'), event('both', like: true, dislike: true)];
    ModelEventOrdering.sortRecommended(rows, isEvent: false, now: today);
    expect(ids(rows), ['both', 'neutral']);
  });
  test('started events use today and then start time, not original date', () {
    final rows = [
      event(
        'old-later',
        date: today.subtract(const Duration(days: 100)),
        time: const TimeOfDay(hour: 11, minute: 0),
      ),
      event(
        'today-earlier',
        date: today,
        time: const TimeOfDay(hour: 9, minute: 0),
      ),
      event(
        'future',
        date: today.add(const Duration(days: 1)),
        time: const TimeOfDay(hour: 0, minute: 0),
      ),
    ];
    ModelEventOrdering.sortRecommended(rows, isEvent: true, now: today);
    expect(ids(rows), ['today-earlier', 'old-later', 'future']);
  });
  test('missing end uses original start and missing time remains last', () {
    final rows = [
      event('no-time', date: today),
      event('today', date: today, time: const TimeOfDay(hour: 9, minute: 0)),
      event(
        'old',
        date: today.subtract(const Duration(days: 1)),
        time: const TimeOfDay(hour: 9, minute: 0),
      ),
    ];
    ModelEventOrdering.sortRecommended(rows, isEvent: true, now: today);
    expect(ids(rows), ['old', 'today', 'no-time']);
  });
  test(
    'recommendation ties preserve incoming order even for duplicate ids',
    () {
      final first = event('same', date: today, name: 'Same');
      final second = event('same', date: today, name: 'Same');
      final rows = [second, first];
      ModelEventOrdering.sortRecommended(rows, isEvent: true, now: today);
      expect(rows[0], same(second));
      expect(rows[1], same(first));
    },
  );
  test(
    'attractions ignore country and dates before comparing city location name',
    () {
      final rows = [
        event('last', date: today, country: 'AA', city: 'Z'),
        event(
          'first',
          date: today.add(const Duration(days: 300)),
          country: 'ZZ',
          city: 'A',
        ),
      ];
      ModelEventOrdering.sortRecommended(rows, isEvent: false, now: today);
      expect(ids(rows), ['first', 'last']);
    },
  );
  test('attractions retain preference before city ordering', () {
    final rows = [
      event('city-a', city: 'A'),
      event('liked-z', city: 'Z', like: true),
      event('disliked-a', city: 'A', dislike: true),
    ];
    ModelEventOrdering.sortRecommended(rows, isEvent: false, now: today);
    expect(ids(rows), ['liked-z', 'city-a', 'disliked-a']);
  });
  test('memory preserves descending date time with ascending place ties', () {
    final rows = [
      event('older', date: today.subtract(const Duration(days: 1))),
      event('late', date: today, time: const TimeOfDay(hour: 11, minute: 0)),
      event(
        'early-z',
        date: today,
        time: const TimeOfDay(hour: 9, minute: 0),
        city: 'Z',
      ),
      event(
        'early-a',
        date: today,
        time: const TimeOfDay(hour: 9, minute: 0),
        city: 'A',
      ),
    ];
    ModelEventOrdering.sortMemory(rows);
    expect(ids(rows), ['late', 'early-a', 'early-z', 'older']);
  });
  test('memory keeps full date precision and ignores preference', () {
    final rows = [
      event('earlier', date: today, like: true),
      event(
        'later',
        date: today.add(const Duration(microseconds: 1)),
        dislike: true,
      ),
    ];
    ModelEventOrdering.sortMemory(rows);
    expect(ids(rows), ['later', 'earlier']);
  });
  test('sort keys are rebuilt after mutable event changes', () {
    final rows = [event('a', city: 'A'), event('b', city: 'B')];
    ModelEventOrdering.sortRecommended(rows, isEvent: false, now: today);
    rows[1].isLike = true;
    ModelEventOrdering.sortRecommended(rows, isEvent: false, now: today);
    expect(ids(rows), ['b', 'a']);
    rows[0].isLike = false;
    rows[0].city = '0';
    ModelEventOrdering.sortRecommended(rows, isEvent: false, now: today);
    expect(ids(rows), ['b', 'a']);
  });
  test('sorting retains list and original event objects', () {
    final a = event('a', city: 'A'), b = event('b', city: 'B');
    final rows = [b, a];
    final alias = rows;
    ModelEventOrdering.sortRecommended(rows, isEvent: false, now: today);
    expect(rows, same(alias));
    expect(rows[0], same(a));
    expect(rows[1], same(b));
  });
  test('model sorting invalidates an already filtered list', () {
    final model = ModelEvent();
    final loc = AppLocalizationsEn();
    final rows = [event('b', city: 'B'), event('a', city: 'A')];
    model.setEvents(rows);
    expect(model.getFilteredEvents(loc).first.id, 'b');
    model.sortRecommendedContent(isEvent: false, now: today);
    expect(model.getFilteredEvents(loc).first.id, 'a');
    model.sortMemoryEvents();
    expect(model.getFilteredEvents(loc).first.id, 'a');
  });
  test('empty and single lists remain valid', () {
    final rows = <EventItem>[];
    ModelEventOrdering.sortRecommended(rows, isEvent: true, now: today);
    ModelEventOrdering.sortMemory(rows);
    expect(rows, isEmpty);
    rows.add(event('only'));
    ModelEventOrdering.sortRecommended(rows, isEvent: true, now: today);
    ModelEventOrdering.sortMemory(rows);
    expect(ids(rows), ['only']);
  });
}

// Frozen original comparators verify all meaningful ordering fields.
class _LegacyOrdering {
  final List<EventItem> _events;
  final DateTime now;
  _LegacyOrdering(this._events, this.now);
  void sortRecommendedContent({required bool isEvent}) {
    final originalOrder = <String, int>{
      for (var index = 0; index < _events.length; index++)
        _events[index].id: index,
    };
    _events.sort((left, right) {
      final preferenceComparison = _preferenceRank(
        left,
      ).compareTo(_preferenceRank(right));
      if (preferenceComparison != 0) return preferenceComparison;

      final contentComparison = isEvent
          ? _compareRecommendedEventDate(left, right)
          : _compareAttraction(left, right);
      if (contentComparison != 0) return contentComparison;
      return originalOrder[left.id]!.compareTo(originalOrder[right.id]!);
    });
  }

  int _preferenceRank(EventItem event) {
    if (event.isLike == true) return 0;
    if (event.isDislike == true) return 2;
    return 1;
  }

  int _compareRecommendedEventDate(EventItem left, EventItem right) {
    final today = DateTimeFormatter.dateOnly(now);
    DateTime effectiveDate(EventItem event) {
      final start = DateTimeFormatter.dateOnly(event.startDate ?? today);
      return start.isBefore(today) ? today : start;
    }

    var comparison = effectiveDate(left).compareTo(effectiveDate(right));
    if (comparison != 0) return comparison;
    comparison = _timeSortValue(
      left.startTime,
    ).compareTo(_timeSortValue(right.startTime));
    if (comparison != 0) return comparison;
    comparison = _effectiveEndDateSortValue(
      left,
    ).compareTo(_effectiveEndDateSortValue(right));
    if (comparison != 0) return comparison;
    comparison = left.country.compareTo(right.country);
    if (comparison != 0) return comparison;
    comparison = left.city.compareTo(right.city);
    if (comparison != 0) return comparison;
    comparison = left.location.compareTo(right.location);
    return comparison != 0 ? comparison : left.name.compareTo(right.name);
  }

  int _compareAttraction(EventItem left, EventItem right) {
    var comparison = left.city.compareTo(right.city);
    if (comparison != 0) return comparison;
    comparison = left.location.compareTo(right.location);
    return comparison != 0 ? comparison : left.name.compareTo(right.name);
  }

  int _timeSortValue(dynamic time) =>
      time == null ? 24 * 60 : time.hour * 60 + time.minute;

  int _effectiveEndDateSortValue(EventItem event) =>
      (event.endDate ?? event.startDate)?.millisecondsSinceEpoch ??
      8640000000000000;

  void sortMemoryEvents() {
    _events.sort((left, right) {
      final leftDate = left.startDate ?? DateTime.fromMillisecondsSinceEpoch(0);
      final rightDate =
          right.startDate ?? DateTime.fromMillisecondsSinceEpoch(0);
      var comparison = rightDate.compareTo(leftDate);
      if (comparison != 0) return comparison;
      comparison = _timeSortValue(
        right.startTime,
      ).compareTo(_timeSortValue(left.startTime));
      if (comparison != 0) return comparison;
      comparison = left.city.compareTo(right.city);
      if (comparison != 0) return comparison;
      comparison = left.location.compareTo(right.location);
      return comparison != 0 ? comparison : left.name.compareTo(right.name);
    });
  }
}
