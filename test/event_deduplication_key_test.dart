import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/event/event_deduplication_key.dart';
import 'package:life_pilot/event/model_event_item.dart';

void main() {
  EventItem buildEvent({
    String id = 'event-1',
    String city = '\u53F0\u5317',
    String masterUrl = 'https://example.com/events/1',
    TimeOfDay? startTime = const TimeOfDay(hour: 14, minute: 30),
  }) {
    return EventItem(
      id: id,
      masterUrl: masterUrl,
      name: ' Test_Event ',
      startDate: DateTime(2026, 8, 20),
      startTime: startTime,
      city: city,
      location: ' \u81FA\u5317\u6D41\u884C\u97F3\u6A02\u4E2D\u5FC3\u200B ',
    );
  }

  group('EventDeduplicationKey', () {
    test('normalizes the city before comparing name keys', () {
      final taipei = buildEvent(city: '\u53F0\u5317');
      final traditionalTaipei = buildEvent(city: '\u81FA\u5317\u5E02');
      final englishTaipei = buildEvent(city: 'Taipei City');

      expect(
        EventDeduplicationKey.byName(traditionalTaipei),
        EventDeduplicationKey.byName(taipei),
      );
      expect(
        EventDeduplicationKey.byName(englishTaipei),
        EventDeduplicationKey.byName(taipei),
      );
    });

    test('keeps different cities as different events', () {
      expect(
        EventDeduplicationKey.byName(buildEvent(city: '\u65B0\u5317')),
        isNot(EventDeduplicationKey.byName(buildEvent(city: '\u53F0\u5317'))),
      );
    });

    test('keeps different start times as different name keys', () {
      expect(
        EventDeduplicationKey.byName(
          buildEvent(startTime: const TimeOfDay(hour: 19, minute: 30)),
        ),
        isNot(EventDeduplicationKey.byName(buildEvent())),
      );
    });

    test('normalizes city and location for id keys', () {
      expect(
        EventDeduplicationKey.byId(buildEvent(city: '\u81FA\u5317\u5E02')),
        EventDeduplicationKey.byId(buildEvent(city: 'Taipei City')),
      );
    });

    test('keeps different sessions from the same source URL separate', () {
      expect(
        EventDeduplicationKey.bySource(
          buildEvent(startTime: const TimeOfDay(hour: 19, minute: 30)),
        ),
        isNot(EventDeduplicationKey.bySource(buildEvent())),
      );
    });

    test('matches events without a start time by their source fields', () {
      expect(
        EventDeduplicationKey.bySource(buildEvent(startTime: null)),
        EventDeduplicationKey.bySource(buildEvent(startTime: null)),
      );
    });

    test('does not create a source key when master URL is missing', () {
      expect(
          EventDeduplicationKey.bySource(buildEvent(masterUrl: '')), isEmpty);
    });
  });
}
