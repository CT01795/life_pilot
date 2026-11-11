import 'package:life_pilot/event/model_event_item.dart';
import 'package:life_pilot/local_storage/local_data_store.dart';
import 'package:life_pilot/utils/supabase.dart';
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

    final response = Map<String, dynamic>.from(
      await supabase.rpc('get_my_calendar_sharing_bootstrap') as Map,
    );
    final invitations = (response['invitations'] as List? ?? const [])
        .map(
          (row) =>
              CalendarShareInvitation.fromJson(Map<String, dynamic>.from(row)),
        )
        .toList();
    final sharedEvents = (response['shared_events'] as List? ?? const [])
        .map(
          (row) => SharedCalendarEvent.fromJson(Map<String, dynamic>.from(row)),
        )
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
    final recipients = emails
        .map((email) => email.trim())
        .toList(growable: false);
    if (recipients.isEmpty) return;
    final selectedIds = List<String>.unmodifiable(eventIds);
    try {
      final result = await supabase.rpc(
        'invite_calendar_viewers',
        params: {'p_invited_emails': recipients, 'p_event_ids': selectedIds},
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
