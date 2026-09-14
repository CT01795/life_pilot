import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/pages/home/model/event/calendar_event.dart';

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
}
