import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/event/event_schedule_data.dart';
import 'package:life_pilot/pages/home/model/event/calendar_event.dart';
import 'package:life_pilot/pages/home/model/event/recommended_event.dart';
import 'package:life_pilot/pages/home/model/place/recommended_place.dart';

void main() {
  const input = <String, dynamic>{
    'id': 'event-1',
    'name': 'Example',
    'start_date': '2026/10/14',
    'start_time': '09:30',
    'end_date': '2026/10/15',
    'end_time': '17:45',
  };

  test('schedule accepts slash dates and preserves date/time output', () {
    final schedule = EventScheduleData.fromJson(input);
    expect(schedule.startDate, DateTime(2026, 10, 14));
    expect(schedule.startTime, const TimeOfDay(hour: 9, minute: 30));
    expect(schedule.toJson(), {
      'start_date': '2026-10-14',
      'start_time': '09:30',
      'end_date': '2026-10-15',
      'end_time': '17:45',
    });
  });

  test('absent dates and times remain null', () {
    expect(EventScheduleData.fromJson({}).toJson(), {
      'start_date': null,
      'start_time': null,
      'end_date': null,
      'end_time': null,
    });
  });

  test('UTC input follows existing local conversion', () {
    final schedule = EventScheduleData.fromJson({
      'start_date': '2026-10-14T23:30:00Z',
    });
    expect(schedule.startDate, DateTime.utc(2026, 10, 14, 23, 30).toLocal());
  });

  test('all dashboard models share the same schedule serialization', () {
    final maps = [
      CalendarEvent.fromJson(input).toJson(),
      RecommendedEvent.fromJson(input).toJson(),
      RecommendedPlace.fromJson(input).toJson(),
    ];
    final expected = EventScheduleData.fromJson(input).toJson();
    for (final map in maps) {
      expect(map['id'], 'event-1');
      expect(map['name'], 'Example');
      for (final entry in expected.entries) {
        expect(map[entry.key], entry.value);
      }
    }
  });
}
