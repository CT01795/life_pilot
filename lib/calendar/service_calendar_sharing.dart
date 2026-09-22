import 'package:life_pilot/event/model_event_item.dart';
import 'package:life_pilot/local_storage/local_data_store.dart';
import 'package:life_pilot/utils/api.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CalendarSharingFailure implements Exception {
  const CalendarSharingFailure(this.code, [this.details]);
  final String code;
  final String? details;
}

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
        .inFilter('status', const ['pending', 'accepted'])
        .order('updated_at', ascending: false);
    final invitations = response
        .map((row) => CalendarShareInvitation.fromJson(row))
        .toList();
    final activeSentInvitationIds = invitations
        .where(
          (item) =>
              item.sharedBy.toLowerCase() == currentEmail &&
              (item.isPending || item.isAccepted),
        )
        .map((item) => item.id)
        .toSet();
    final sharedEventResponse = await supabase.rpc(
      'get_my_shared_calendar_events',
    );
    final sharedEvents = (sharedEventResponse as List<dynamic>)
        .map((row) => SharedCalendarEvent.fromJson(row as Map<String, dynamic>))
        .where((event) => activeSentInvitationIds.contains(event.invitationId))
        .toList();

    final shareableEvents =
        visibleEvents
            .where(
              (event) =>
                  event.account?.trim().toLowerCase() == currentEmail &&
                  event.startDate != null,
            )
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
          .where(
            (item) =>
                item.sharedBy.toLowerCase() == currentEmail &&
                (item.isPending || item.isAccepted),
          )
          .toList(),
      received: invitations
          .where(
            (item) =>
                item.invitedEmail.toLowerCase() == currentEmail &&
                (item.isPending || item.isAccepted),
          )
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
      try {
        final result = await supabase.rpc(
          'invite_calendar_viewer',
          params: {
            'p_invited_email': email.trim(),
            'p_event_ids': eventIds.toList(),
          },
        );
        if (result is Map && result['ok'] != true) {
          throw CalendarSharingFailure(
            result['error']?.toString() ?? 'unknown',
            result['details']?.toString(),
          );
        }
      } on PostgrestException catch (error) {
        throw _translateFailure(error);
      }
    }
  }

  Future<void> respond({
    required String invitationId,
    required bool accept,
  }) async {
    await _requireCloudMode();
    try {
      await supabase.rpc(
        'respond_calendar_invitation',
        params: {'p_invitation_id': invitationId, 'p_accept': accept},
      );
    } on PostgrestException catch (error) {
      throw _translateFailure(error);
    }
  }

  Future<void> revoke(String invitationId) async {
    await _requireCloudMode();
    try {
      await supabase.rpc(
        'revoke_calendar_invitation',
        params: {'p_invitation_id': invitationId},
      );
    } on PostgrestException catch (error) {
      throw _translateFailure(error);
    }
  }

  Future<void> removeSharedEvent({
    required String invitationId,
    required String eventId,
  }) async {
    await _requireCloudMode();
    try {
      await supabase.rpc(
        'remove_calendar_shared_event',
        params: {'p_invitation_id': invitationId, 'p_event_id': eventId},
      );
    } on PostgrestException catch (error) {
      throw _translateFailure(error);
    }
  }

  CalendarSharingFailure _translateFailure(PostgrestException error) {
    final rawMessage = [
      error.message,
      error.details,
      error.hint,
      error.code,
    ].whereType<Object>().join(' ');
    final message = rawMessage.toUpperCase();
    if (message.contains('QUOTA_REACHED') ||
        message.contains('RENEWAL_REQUIRED')) {
      return const CalendarSharingFailure('quota');
    }
    if (message.contains('DUPLICATE_INVITATION')) {
      return const CalendarSharingFailure('duplicate');
    }
    if (message.contains('ACCOUNT_NOT_FOUND')) {
      return const CalendarSharingFailure('account_not_found');
    }
    if (message.contains('INVALID EMAIL')) {
      return const CalendarSharingFailure('invalid_email');
    }
    if (message.contains('CANNOT INVITE YOURSELF')) {
      return const CalendarSharingFailure('self_invite');
    }
    if (message.contains('NO OWNED EVENTS SELECTED') ||
        message.contains('SHARED EVENT NOT FOUND')) {
      return const CalendarSharingFailure('event_unavailable');
    }
    if (message.contains('INVITATION CANNOT BE UPDATED') ||
        message.contains('INVITATION NOT FOUND')) {
      return const CalendarSharingFailure('stale_invitation');
    }
    return CalendarSharingFailure('unknown', rawMessage);
  }
}
