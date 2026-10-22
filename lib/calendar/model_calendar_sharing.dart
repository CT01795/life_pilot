import 'package:life_pilot/event/model_event_item.dart';
import 'package:life_pilot/utils/const.dart';
import 'package:life_pilot/utils/text_normalization.dart';
import 'package:life_pilot/utils/value_parser.dart';

class CalendarShareableEvent {
  const CalendarShareableEvent({
    required this.id,
    required this.name,
    required this.startDate,
  });
  final String id;
  final String name;
  final DateTime? startDate;
  factory CalendarShareableEvent.fromJson(Map<String, dynamic> json) =>
      CalendarShareableEvent(
        id: parseStringValue(json[Fields.id]),
        name: parseStringValue(json['name']).trim().isNotEmpty
            ? parseStringValue(json['name'])
            : '-',
        startDate: tryParseDateTimeValue(json['start_date']),
      );
}

class SharedCalendarEvent {
  const SharedCalendarEvent({
    required this.invitationId,
    required this.eventId,
    required this.name,
    required this.startDate,
  });
  final String invitationId;
  final String eventId;
  final String name;
  final DateTime? startDate;
  factory SharedCalendarEvent.fromJson(Map<String, dynamic> json) =>
      SharedCalendarEvent(
        invitationId: parseStringValue(json['invitation_id']),
        eventId: parseStringValue(json['event_id']),
        name: parseStringValue(json['event_name']).trim().isNotEmpty
            ? parseStringValue(json['event_name'])
            : '-',
        startDate: tryParseDateTimeValue(json['start_date']),
      );
}

class CalendarShareInvitation {
  const CalendarShareInvitation({
    required this.id,
    required this.sharedBy,
    required this.invitedEmail,
    required this.status,
  });
  final String id;
  final String sharedBy;
  final String invitedEmail;
  final String status;
  bool get isPending => status == 'pending';
  bool get isAccepted => status == 'accepted';
  factory CalendarShareInvitation.fromJson(Map<String, dynamic> json) =>
      CalendarShareInvitation(
        id: parseStringValue(json[Fields.id]),
        sharedBy: parseStringValue(json['shared_by']),
        invitedEmail: parseStringValue(json['invited_email']),
        status: parseStringValue(json['status'], fallback: 'pending'),
      );
}

/// Sharing projection only: no authentication, network, persistence or widgets.
class CalendarSharingState {
  CalendarSharingState({
    required this.sent,
    required this.received,
    required this.shareableEvents,
    required this.sharedEvents,
  }) : _sharedEventsByInvitation = _groupSharedEvents(sharedEvents);

  factory CalendarSharingState.fromData({
    required String currentEmail,
    required Iterable<CalendarShareInvitation> invitations,
    required Iterable<SharedCalendarEvent> sharedEvents,
    required Iterable<EventItem> visibleEvents,
  }) {
    final owner = normalizeText(currentEmail);
    // Many visible events share an author. Keep normalization local to this
    // projection so neither account changes nor edits can reuse old ownership.
    final normalizedAccounts = <String?, String>{};
    bool belongsToCurrentAccount(String? account) =>
        (normalizedAccounts[account] ??= normalizeText(account)) == owner;

    final sent = <CalendarShareInvitation>[];
    final received = <CalendarShareInvitation>[];
    final activeSentIds = <String>{};
    for (final invitation in invitations) {
      if (!invitation.isPending && !invitation.isAccepted) continue;
      if (belongsToCurrentAccount(invitation.sharedBy)) {
        sent.add(invitation);
        activeSentIds.add(invitation.id);
      }
      if (belongsToCurrentAccount(invitation.invitedEmail)) {
        received.add(invitation);
      }
    }
    // Deduplicate before constructing display rows. Last matching ID wins,
    // while its original insertion position is retained, as before.
    final byId = <String, EventItem>{};
    for (final event in visibleEvents) {
      if (belongsToCurrentAccount(event.account) && event.startDate != null) {
        byId[event.id] = event;
      }
    }
    final shareable = [
      for (final event in byId.values)
        CalendarShareableEvent(
          id: event.id,
          name: event.name.trim().isEmpty ? '-' : event.name,
          startDate: event.startDate,
        ),
    ]..sort((a, b) => a.startDate!.compareTo(b.startDate!));
    return CalendarSharingState(
      sent: sent,
      received: received,
      shareableEvents: shareable,
      sharedEvents: sharedEvents
          .where((event) => activeSentIds.contains(event.invitationId))
          .toList(),
    );
  }

  final List<CalendarShareInvitation> sent;
  final List<CalendarShareInvitation> received;
  final List<CalendarShareableEvent> shareableEvents;
  final List<SharedCalendarEvent> sharedEvents;
  final Map<String, List<SharedCalendarEvent>> _sharedEventsByInvitation;
  List<SharedCalendarEvent> eventsForInvitation(String invitationId) =>
      _sharedEventsByInvitation[invitationId] ?? const [];
  static Map<String, List<SharedCalendarEvent>> _groupSharedEvents(
    List<SharedCalendarEvent> events,
  ) {
    final grouped = <String, List<SharedCalendarEvent>>{};
    for (final event in events) {
      grouped.putIfAbsent(event.invitationId, () => []).add(event);
    }
    return grouped;
  }
}
