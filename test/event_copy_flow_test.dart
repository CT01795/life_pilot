import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/event/event_copy_flow.dart';
import 'package:life_pilot/event/model_event_item.dart';
import 'package:life_pilot/utils/const.dart';

void main() {
  group('event copy destinations', () {
    test('an owned calendar event can copy to the other three pages', () {
      final destinations = availableEventCopyDestinations(
        sourceTableName: TableNames.calendarEvents,
        isOwnCalendarEvent: true,
      );

      expect(destinations, isNot(contains(EventCopyDestination.calendar)));
      expect(destinations, hasLength(3));
    });

    test('a shared calendar event can also copy into my calendar', () {
      final destinations = availableEventCopyDestinations(
        sourceTableName: TableNames.calendarEvents,
        isOwnCalendarEvent: false,
      );

      expect(destinations, contains(EventCopyDestination.calendar));
      expect(destinations, hasLength(4));
    });

    test('recommended content does not offer its current page', () {
      final destinations = availableEventCopyDestinations(
        sourceTableName: TableNames.recommendEvents,
        isOwnCalendarEvent: false,
      );

      expect(
        destinations,
        isNot(contains(EventCopyDestination.recommendedEvent)),
      );
      expect(destinations, hasLength(3));
    });
  });

  test('copy template is independent and resets ownership and state', () {
    final source = EventItem(
      id: 'source',
      account: 'owner@example.com',
      name: 'Festival',
      startDate: DateTime(2026, 10, 20),
      startTime: const TimeOfDay(hour: 10, minute: 30),
      isCompleted: true,
      isApproved: true,
      isLike: true,
      pageViews: 99,
      subEvents: [EventItem(id: 'sub', name: 'Session')],
    );

    final copy = buildEventCopyTemplate(
      source,
      currentAccount: 'viewer@example.com',
    );

    expect(copy.id, isNot(source.id));
    expect(copy.account, 'viewer@example.com');
    expect(copy.name, source.name);
    expect(copy.startDate, source.startDate);
    expect(copy.startTime, source.startTime);
    expect(copy.isCompleted, isFalse);
    expect(copy.isApproved, isFalse);
    expect(copy.isLike, isNull);
    expect(copy.pageViews, 0);
    expect(copy.subEvents.single.id, isNot(source.subEvents.single.id));
    expect(source.isApproved, isTrue);
    expect(source.account, 'owner@example.com');
  });
}
