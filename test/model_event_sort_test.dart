import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/event/model_event.dart';
import 'package:life_pilot/event/model_event_item.dart';
import 'package:life_pilot/l10n/app_localizations_en.dart';
import 'package:life_pilot/utils/date_time.dart';

void main() {
  final loc = AppLocalizationsEn();

  test('recommended events sort by preference then requested event fields', () {
    final today = DateTimeFormatter.dateOnly(DateTime.now());
    final model = ModelEvent();
    model.setEvents([
      _event(id: 'neutral', startDate: today),
      _event(
        id: 'liked-later',
        isLike: true,
        startDate: today.add(const Duration(days: 2)),
      ),
      _event(id: 'disliked', isDislike: true, startDate: today),
      _event(
        id: 'liked-started',
        isLike: true,
        startDate: today.subtract(const Duration(days: 3)),
        endDate: today.add(const Duration(days: 1)),
      ),
    ]);

    model.sortRecommendedContent(isEvent: true);

    expect(model.getFilteredEvents(loc).map((event) => event.id), [
      'liked-started',
      'liked-later',
      'neutral',
      'disliked',
    ]);
  });

  test('recommended event ties sort by time end date country and location', () {
    final today = DateTimeFormatter.dateOnly(DateTime.now());
    final model = ModelEvent();
    model.setEvents([
      _event(
        id: 'name-b',
        name: 'B',
        city: 'Taipei',
        location: 'Hall A',
        startDate: today,
        startTime: const TimeOfDay(hour: 10, minute: 0),
      ),
      _event(
        id: 'earlier-end-date',
        country: 'TW',
        city: 'Taipei',
        location: 'Hall Z',
        startDate: today.subtract(const Duration(days: 5)),
        startTime: const TimeOfDay(hour: 10, minute: 0),
        endDate: today,
      ),
      _event(
        id: 'location-b',
        name: 'A',
        country: 'TW',
        city: 'Taipei',
        location: 'Hall B',
        startDate: today,
        startTime: const TimeOfDay(hour: 10, minute: 0),
        endDate: today.add(const Duration(days: 2)),
      ),
      _event(
        id: 'earlier-time',
        city: 'Taipei',
        location: 'Hall Z',
        startDate: today,
        startTime: const TimeOfDay(hour: 9, minute: 0),
      ),
    ]);

    model.sortRecommendedContent(isEvent: true);

    expect(model.getFilteredEvents(loc).map((event) => event.id), [
      'earlier-time',
      'name-b',
      'earlier-end-date',
      'location-b',
    ]);
  });

  test('attractions sort by city location and name', () {
    final model = ModelEvent();
    model.setEvents([
      _event(id: 'name-b', city: 'Taipei', location: 'Hall A', name: 'B'),
      _event(id: 'location-b', city: 'Taipei', location: 'Hall B', name: 'A'),
      _event(id: 'city-first', city: 'Kaohsiung', location: 'Zoo', name: 'Z'),
    ]);

    model.sortRecommendedContent(isEvent: false);

    expect(model.getFilteredEvents(loc).map((event) => event.id), [
      'city-first',
      'name-b',
      'location-b',
    ]);
  });

  test('memory batches append without duplicates and remain newest first', () {
    final today = DateTimeFormatter.dateOnly(DateTime.now());
    final model = ModelEvent();
    model.setEvents([_event(id: 'newest', startDate: today)]);

    model.appendMemoryEvents([
      _event(id: 'older', startDate: today.subtract(const Duration(days: 20))),
      _event(id: 'newest', startDate: today),
    ]);

    expect(model.getFilteredEvents(loc).map((event) => event.id), [
      'newest',
      'older',
    ]);
  });
}

EventItem _event({
  required String id,
  String name = 'Event',
  String country = 'TW',
  String city = '',
  String location = '',
  DateTime? startDate,
  DateTime? endDate,
  TimeOfDay? startTime,
  bool? isLike,
  bool? isDislike,
}) {
  return EventItem(
    id: id,
    name: name,
    country: country,
    city: city,
    location: location,
    startDate: startDate,
    endDate: endDate,
    startTime: startTime,
    isLike: isLike,
    isDislike: isDislike,
  );
}
