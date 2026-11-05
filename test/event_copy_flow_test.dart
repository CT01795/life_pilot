import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/event/event_copy_flow.dart';
import 'package:life_pilot/event/model_event_item.dart';

void main() {
  group('event copy destinations', () {
    for (final destination in EventCopyDestination.values) {
      test('can copy into the same page: ${destination.name}', () {
        final destinations = availableEventCopyDestinations();
        expect(destinations, contains(destination));
        expect(destinations, hasLength(4));
        expect(() => destinations.clear(), throwsUnsupportedError);
      });
    }
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
    expect(copy.subEvents.single.account, 'viewer@example.com');
    final secondCopy = buildEventCopyTemplate(
      source,
      currentAccount: source.account!,
    );
    expect(secondCopy.id, isNot(source.id));
    expect(secondCopy.id, isNot(copy.id));
    expect(secondCopy.account, source.account);
    expect(source.isApproved, isTrue);
    expect(source.account, 'owner@example.com');
  });
}
