import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/pages/home/model/event/calendar_event.dart';
import 'package:life_pilot/pages/home/model/event/recommended_event.dart';
import 'package:life_pilot/pages/home/model/place/recommended_place.dart';

void main() {
  test('calendar event defaults missing country to Taiwan', () {
    final event = CalendarEvent.fromJson(const {
      'id': 'event-1',
      'name': 'Event',
    });

    expect(event.country, 'TW');
    expect(event.toJson()['country'], 'TW');
  });

  test('calendar event normalizes a country name for memory writes', () {
    final event = CalendarEvent.fromJson(const {
      'id': 'event-1',
      'name': 'Event',
      'country': 'Japan',
    });

    expect(event.country, 'JP');
  });

  test('recommended content keeps its country when added to a calendar', () {
    final event = RecommendedEvent.fromJson(const {
      'id': 'event-1',
      'name': 'Singapore event',
      'country': 'Singapore',
    });
    final place = RecommendedPlace.fromJson(const {
      'id': 'place-1',
      'name': 'Japan place',
      'country': 'Japan',
    });

    expect(event.country, 'SG');
    expect(event.toJson()['country'], 'SG');
    expect(place.country, 'JP');
    expect(place.toJson()['country'], 'JP');
  });
}
