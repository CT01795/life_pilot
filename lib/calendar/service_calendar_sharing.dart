import 'package:life_pilot/event/model_event_item.dart';
import 'package:life_pilot/local_storage/local_data_store.dart';
import 'package:life_pilot/utils/api.dart';

class CalendarShareableEvent {
  const CalendarShareableEvent({
    required this.id,
    required this.name,
    required this.startDate,
  });

  final String id;
  final String name;
  final DateTime? startDate;

  factory CalendarShareableEvent.fromJson(Map<String, dynamic> json) {
    return CalendarShareableEvent(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString().trim().isNotEmpty == true
          ? json['name'].toString()
          : '-',
      startDate: DateTime.tryParse(json['start_date']?.toString() ?? ''),
    );
  }
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

  factory SharedCalendarEvent.fromJson(Map<String, dynamic> json) {
    return SharedCalendarEvent(
      invitationId: json['invitation_id']?.toString() ?? '',
      eventId: json['event_id']?.toString() ?? '',
      name: json['event_name']?.toString().trim().isNotEmpty == true
          ? json['event_name'].toString()
          : '-',
      startDate: DateTime.tryParse(json['start_date']?.toString() ?? ''),
    );
  }
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

  factory CalendarShareInvitation.fromJson(Map<String, dynamic> json) {
    return CalendarShareInvitation(
      id: json['id']?.toString() ?? '',
      sharedBy: json['shared_by']?.toString() ?? '',
      invitedEmail: json['invited_email']?.toString() ?? '',
      status: json['status']?.toString() ?? 'pending',
    );
  }
}

class CalendarSharingState {
  CalendarSharingState({
    required this.sent,
    required this.received,
    required this.shareableEvents,
    required this.sharedEvents,
  }) : _sharedEventsByInvitation = _groupSharedEvents(sharedEvents);

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

class ServiceCalendarSharing {
  Future<String> _requireCloudMode() async {
    final email = supabase.auth.currentUser?.email?.trim().toLowerCase();
    if (email == null || email.isEmpty) {
      throw StateError('User must be signed in.');
    }
    final storage = await LocalDataStore.instance.preferredLocation(email);
    if (storage == DataStorageLocation.local) {
      throw StateError('Calendar sharing is unavailable in local mode.');
    }
    return email;
  }

  Future<CalendarSharingState> load({
    required Iterable<EventItem> visibleEvents,
  }) async {
    final currentEmail = await _requireCloudMode();

    final response = await supabase
        .from('calendar_share_invitations')
        .select('id, shared_by, invited_email, status')
        .order('updated_at', ascending: false);
    final invitations =
        response.map((row) => CalendarShareInvitation.fromJson(row)).toList();
    final sharedEventResponse =
        await supabase.rpc('get_my_shared_calendar_events');
    final sharedEvents = (sharedEventResponse as List<dynamic>)
        .map((row) => SharedCalendarEvent.fromJson(row as Map<String, dynamic>))
        .toList();

    final shareableEvents = visibleEvents
        .where((event) =>
            event.account?.trim().toLowerCase() == currentEmail &&
            event.startDate != null)
        .map(
          (event) => CalendarShareableEvent(
            id: event.id,
            name: event.name.trim().isEmpty ? '-' : event.name,
            startDate: event.startDate,
          ),
        )
        .fold<Map<String, CalendarShareableEvent>>(
          {},
          (eventsById, event) => eventsById..[event.id] = event,
        )
        .values
        .toList()
      ..sort((a, b) => a.startDate!.compareTo(b.startDate!));

    return CalendarSharingState(
      sent: invitations
          .where((item) => item.sharedBy.toLowerCase() == currentEmail)
          .toList(),
      received: invitations
          .where((item) => item.invitedEmail.toLowerCase() == currentEmail)
          .toList(),
      shareableEvents: shareableEvents,
      sharedEvents: sharedEvents,
    );
  }

  Future<void> inviteAll(
    Iterable<String> emails,
    Iterable<String> eventIds,
  ) async {
    await _requireCloudMode();
    for (final email in emails) {
      await supabase.rpc(
        'invite_calendar_viewer',
        params: {
          'p_invited_email': email.trim(),
          'p_event_ids': eventIds.toList(),
        },
      );
    }
  }

  Future<void> respond({
    required String invitationId,
    required bool accept,
  }) async {
    await _requireCloudMode();
    await supabase.rpc(
      'respond_calendar_invitation',
      params: {
        'p_invitation_id': invitationId,
        'p_accept': accept,
      },
    );
  }

  Future<void> revoke(String invitationId) async {
    await _requireCloudMode();
    await supabase.rpc(
      'revoke_calendar_invitation',
      params: {'p_invitation_id': invitationId},
    );
  }

  Future<void> removeSharedEvent({
    required String invitationId,
    required String eventId,
  }) async {
    await _requireCloudMode();
    await supabase.rpc(
      'remove_calendar_shared_event',
      params: {
        'p_invitation_id': invitationId,
        'p_event_id': eventId,
      },
    );
  }
}
