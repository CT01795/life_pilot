import 'package:life_pilot/event/model_event_item.dart';
import 'package:life_pilot/local_storage/local_data_store.dart';
import 'package:life_pilot/utils/api.dart';
import 'package:life_pilot/calendar/model_calendar_sharing.dart';
import 'package:life_pilot/calendar/model_calendar_sharing_failure.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:life_pilot/utils/text_normalization.dart';
import 'package:life_pilot/utils/value_parser.dart';

// Keep existing imports source-compatible while models live outside Service.
export 'package:life_pilot/calendar/model_calendar_sharing.dart';
export 'package:life_pilot/calendar/model_calendar_sharing_failure.dart';

class ServiceCalendarSharing {
  ServiceCalendarSharing({LocalDataStore? localStore})
    : _localStore = localStore ?? LocalDataStore.instance;
  final LocalDataStore _localStore;

  Future<String> _requireCloudMode() async {
    final email = normalizeText(supabase.auth.currentUser?.email);
    if (email.isEmpty) {
      throw StateError('User must be signed in.');
    }
    final storage = await _localStore.preferredLocation(email);
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
    final sharedEventResponse = await supabase.rpc(
      'get_my_shared_calendar_events',
    );
    final sharedEvents = (sharedEventResponse as List<dynamic>)
        .map((row) => SharedCalendarEvent.fromJson(row as Map<String, dynamic>))
        .toList();
    return CalendarSharingState.fromData(
      currentEmail: currentEmail,
      invitations: invitations,
      visibleEvents: visibleEvents,
      sharedEvents: sharedEvents,
    );
  }

  Future<void> inviteAll(
    Iterable<String> emails,
    Iterable<String> eventIds,
  ) async {
    await _requireCloudMode();
    // One stable selection for the whole sequential batch, even if the caller
    // changes its UI selections while an earlier RPC is awaiting a response.
    final recipients = List<String>.of(emails, growable: false);
    if (recipients.isEmpty) return;
    final selectedIds = List<String>.unmodifiable(eventIds);
    for (final email in recipients) {
      try {
        final result = await supabase.rpc(
          'invite_calendar_viewer',
          params: {'p_invited_email': email.trim(), 'p_event_ids': selectedIds},
        );
        if (result is Map && result['ok'] != true) {
          throw CalendarSharingFailure(
            parseStringValue(result['error'], fallback: 'unknown'),
            parseOptionalStringValue(result['details']),
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

  CalendarSharingFailure _translateFailure(PostgrestException error) =>
      CalendarSharingFailure.fromFields(
        message: error.message,
        details: error.details,
        hint: error.hint,
        code: error.code,
      );
}
