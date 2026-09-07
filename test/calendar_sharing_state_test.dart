import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/calendar/service_calendar_sharing.dart';

void main() {
  test('CalendarSharingState groups shared events by invitation', () {
    const first = SharedCalendarEvent(
      invitationId: 'invite-a',
      eventId: 'event-1',
      name: 'First',
      startDate: null,
    );
    const second = SharedCalendarEvent(
      invitationId: 'invite-b',
      eventId: 'event-2',
      name: 'Second',
      startDate: null,
    );
    const third = SharedCalendarEvent(
      invitationId: 'invite-a',
      eventId: 'event-3',
      name: 'Third',
      startDate: null,
    );
    final state = CalendarSharingState(
      sent: const [],
      received: const [],
      shareableEvents: const [],
      sharedEvents: const [first, second, third],
    );

    expect(state.eventsForInvitation('invite-a'), [first, third]);
    expect(state.eventsForInvitation('invite-b'), [second]);
    expect(state.eventsForInvitation('missing'), isEmpty);
  });
}
