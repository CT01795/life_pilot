import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/calendar/model_calendar_sharing.dart';
import 'package:life_pilot/event/model_event_item.dart';

const owner = 'one@example.com';
CalendarShareInvitation invitation(
  String id,
  String sender,
  String recipient,
  String status,
) => CalendarShareInvitation(
  id: id,
  sharedBy: sender,
  invitedEmail: recipient,
  status: status,
);
SharedCalendarEvent shared(String invitationId, String eventId) =>
    SharedCalendarEvent(
      invitationId: invitationId,
      eventId: eventId,
      name: eventId,
      startDate: null,
    );
EventItem event(
  String id,
  DateTime? date, {
  String account = owner,
  String? name,
}) => EventItem(id: id, name: name ?? id, startDate: date, account: account);

void main() {
  test('missing and blank authors cannot match a signed-in account', () {
    final missing = event('missing', DateTime(2026))..account = null;
    final state = CalendarSharingState.fromData(
      currentEmail: owner,
      invitations: [],
      sharedEvents: [],
      visibleEvents: [
        missing,
        missing,
        event('blank', DateTime(2026), account: ' '),
        event('own', DateTime(2026)),
      ],
    );
    expect(state.shareableEvents.map((e) => e.id), ['own']);
  });

  test(
    'current email and repeated account variants use the same owner rule',
    () {
      final state = CalendarSharingState.fromData(
        currentEmail: ' ONE@EXAMPLE.COM ',
        invitations: [
          invitation('sent', owner, 'other@example.com', 'pending'),
          invitation(
            'received',
            'other@example.com',
            ' One@Example.com ',
            'accepted',
          ),
          invitation('closed', owner, 'other@example.com', 'rejected'),
        ],
        sharedEvents: [shared('sent', 'detail'), shared('closed', 'old')],
        visibleEvents: [
          for (var i = 0; i < 1000; i++)
            event(
              '$i',
              DateTime(2026),
              account: i.isEven ? owner : ' ONE@example.com ',
            ),
          event('foreign', DateTime(2026), account: 'other@example.com'),
        ],
      );
      expect(state.sent.map((e) => e.id), ['sent']);
      expect(state.received.map((e) => e.id), ['received']);
      expect(state.shareableEvents.length, 1000);
      expect(state.shareableEvents.any((e) => e.id == 'foreign'), isFalse);
      expect(state.sharedEvents.map((e) => e.eventId), ['detail']);
    },
  );

  test(
    'account normalization never carries ownership into a later projection',
    () {
      final rows = [
        event('one', DateTime(2026)),
        event('two', DateTime(2026), account: 'two@example.com'),
      ];
      final invitations = [
        invitation('share', owner, 'two@example.com', 'accepted'),
      ];
      CalendarSharingState project(String email) =>
          CalendarSharingState.fromData(
            currentEmail: email,
            invitations: invitations,
            sharedEvents: [shared('share', 'one')],
            visibleEvents: rows,
          );
      final first = project(owner);
      final second = project(' TWO@EXAMPLE.COM ');
      expect(first.sent, hasLength(1));
      expect(first.shareableEvents.single.id, 'one');
      expect(second.sent, isEmpty);
      expect(second.received, hasLength(1));
      expect(second.shareableEvents.single.id, 'two');
      expect(second.sharedEvents, isEmpty);
    },
  );

  test(
    'rebuilt projection sees changed event owners rather than cached owners',
    () {
      final row = event('event', DateTime(2026));
      CalendarSharingState project() => CalendarSharingState.fromData(
        currentEmail: owner,
        invitations: [],
        sharedEvents: [],
        visibleEvents: [row],
      );
      expect(project().shareableEvents, hasLength(1));
      row.account = 'other@example.com';
      expect(project().shareableEvents, isEmpty);
      row.account = ' ONE@example.com ';
      expect(project().shareableEvents, hasLength(1));
    },
  );

  test('empty inputs produce empty sharing lists', () {
    final state = CalendarSharingState.fromData(
      currentEmail: owner,
      invitations: [],
      sharedEvents: [],
      visibleEvents: [],
    );
    expect(state.sent, isEmpty);
    expect(state.received, isEmpty);
    expect(state.shareableEvents, isEmpty);
    expect(state.eventsForInvitation('missing'), isEmpty);
  });
  test(
    'active invitation classification retains response order and normalization',
    () {
      final rows = [
        invitation('sent1', ' ONE@example.com ', 'two@example.com', 'pending'),
        invitation(
          'received',
          'two@example.com',
          ' ONE@example.com ',
          'accepted',
        ),
        invitation('rejected', owner, 'two@example.com', 'rejected'),
        invitation('revoked', 'two@example.com', owner, 'revoked'),
        invitation('other', 'two@example.com', 'three@example.com', 'pending'),
        invitation('sent2', owner, 'three@example.com', 'accepted'),
      ];
      final state = CalendarSharingState.fromData(
        currentEmail: owner,
        invitations: rows,
        sharedEvents: [],
        visibleEvents: [],
      );
      expect(state.sent.map((e) => e.id), ['sent1', 'sent2']);
      expect(state.received.map((e) => e.id), ['received']);
      expect(rows, hasLength(6));
    },
  );
  test(
    'shared details retain only active sent invitation IDs and source order',
    () {
      final rows = [
        shared('pending', 'p1'),
        shared('received', 'r1'),
        shared('old', 'old'),
        shared('accepted', 'a1'),
        shared('pending', 'p2'),
      ];
      final state = CalendarSharingState.fromData(
        currentEmail: owner,
        invitations: [
          invitation('pending', owner, 'two@example.com', 'pending'),
          invitation('accepted', owner, 'two@example.com', 'accepted'),
          invitation('received', 'two@example.com', owner, 'accepted'),
          invitation('old', owner, 'two@example.com', 'rejected'),
        ],
        sharedEvents: rows,
        visibleEvents: [],
      );
      expect(state.sharedEvents.map((e) => e.eventId), ['p1', 'a1', 'p2']);
      expect(state.eventsForInvitation('pending').map((e) => e.eventId), [
        'p1',
        'p2',
      ]);
      expect(rows, hasLength(5));
    },
  );
  test(
    'shareable events preserve past dates, owner filter and last duplicate',
    () {
      final rows = List<EventItem>.unmodifiable([
        event('duplicate', DateTime(2026, 10), name: 'old name'),
        event('foreign', DateTime(2026), account: 'two@example.com'),
        event('undated', null),
        event('past', DateTime(2020), name: ' '),
        event('duplicate', DateTime(2027), name: 'new name'),
        event('normalized', DateTime(2026), account: ' ONE@example.com '),
      ]);
      final state = CalendarSharingState.fromData(
        currentEmail: owner,
        invitations: [],
        sharedEvents: [],
        visibleEvents: rows,
      );
      expect(state.shareableEvents.map((e) => e.id), [
        'past',
        'normalized',
        'duplicate',
      ]);
      expect(state.shareableEvents.first.name, '-');
      expect(state.shareableEvents.last.name, 'new name');
      expect(rows.first.name, 'old name');
    },
  );
  test('ineligible duplicate cannot overwrite an eligible event', () {
    final state = CalendarSharingState.fromData(
      currentEmail: owner,
      invitations: [],
      sharedEvents: [],
      visibleEvents: [
        event('same', DateTime(2026), name: 'keep'),
        event('same', null, name: 'no date'),
        event('same', DateTime(2027), account: 'other@example.com'),
      ],
    );
    expect(state.shareableEvents.single.name, 'keep');
  });
  test('projection consumes invitation and event iterables only once', () {
    var invitationPasses = 0, eventPasses = 0;
    Iterable<CalendarShareInvitation> invitations() sync* {
      if (++invitationPasses > 1) throw StateError('Repeated invitation scan');
      yield invitation('one', owner, 'two@example.com', 'pending');
    }

    Iterable<EventItem> events() sync* {
      if (++eventPasses > 1) throw StateError('Repeated visible event scan');
      yield event('event', DateTime(2026));
    }

    final state = CalendarSharingState.fromData(
      currentEmail: owner,
      invitations: invitations(),
      sharedEvents: [],
      visibleEvents: events(),
    );
    expect(state.sent, hasLength(1));
    expect(state.shareableEvents, hasLength(1));
    expect([invitationPasses, eventPasses], [1, 1]);
  });
}
