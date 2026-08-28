import 'package:life_pilot/utils/api.dart';

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
      id: json['id'] as String,
      sharedBy: json['shared_by'] as String,
      invitedEmail: json['invited_email'] as String,
      status: json['status'] as String,
    );
  }
}

class CalendarSharingState {
  const CalendarSharingState({
    required this.sent,
    required this.received,
  });

  final List<CalendarShareInvitation> sent;
  final List<CalendarShareInvitation> received;
}

class ServiceCalendarSharing {
  Future<CalendarSharingState> load() async {
    final currentEmail = supabase.auth.currentUser?.email?.toLowerCase();
    if (currentEmail == null || currentEmail.isEmpty) {
      return const CalendarSharingState(sent: [], received: []);
    }

    final response = await supabase
        .from('calendar_share_invitations')
        .select('id, shared_by, invited_email, status')
        .order('updated_at', ascending: false);
    final invitations =
        response.map((row) => CalendarShareInvitation.fromJson(row)).toList();

    return CalendarSharingState(
      sent: invitations
          .where((item) => item.sharedBy.toLowerCase() == currentEmail)
          .toList(),
      received: invitations
          .where((item) => item.invitedEmail.toLowerCase() == currentEmail)
          .toList(),
    );
  }

  Future<void> inviteAll(Iterable<String> emails) async {
    for (final email in emails) {
      await supabase.rpc(
        'invite_calendar_viewer',
        params: {'p_invited_email': email.trim()},
      );
    }
  }

  Future<void> respond({
    required String invitationId,
    required bool accept,
  }) async {
    await supabase.rpc(
      'respond_calendar_invitation',
      params: {
        'p_invitation_id': invitationId,
        'p_accept': accept,
      },
    );
  }

  Future<void> revoke(String invitationId) async {
    await supabase.rpc(
      'revoke_calendar_invitation',
      params: {'p_invitation_id': invitationId},
    );
  }
}
