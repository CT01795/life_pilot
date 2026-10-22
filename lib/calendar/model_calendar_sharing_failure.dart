/// Sharing error classification only; no transport types, widgets or locale.
class CalendarSharingFailure implements Exception {
  const CalendarSharingFailure(this.code, [this.details]);
  final String code;
  final String? details;

  factory CalendarSharingFailure.fromFields({
    String? message,
    Object? details,
    String? hint,
    String? code,
  }) {
    final raw = [message, details, hint, code].whereType<Object>().join(' ');
    final text = raw.toUpperCase();
    if (text.contains('QUOTA_REACHED') || text.contains('RENEWAL_REQUIRED')) {
      return const CalendarSharingFailure('quota');
    }
    if (text.contains('DUPLICATE_INVITATION')) {
      return const CalendarSharingFailure('duplicate');
    }
    if (text.contains('ACCOUNT_NOT_FOUND')) {
      return const CalendarSharingFailure('account_not_found');
    }
    if (text.contains('INVALID EMAIL')) {
      return const CalendarSharingFailure('invalid_email');
    }
    if (text.contains('CANNOT INVITE YOURSELF')) {
      return const CalendarSharingFailure('self_invite');
    }
    if (text.contains('NO OWNED EVENTS SELECTED') ||
        text.contains('SHARED EVENT NOT FOUND')) {
      return const CalendarSharingFailure('event_unavailable');
    }
    if (text.contains('INVITATION CANNOT BE UPDATED') ||
        text.contains('INVITATION NOT FOUND')) {
      return const CalendarSharingFailure('stale_invitation');
    }
    return CalendarSharingFailure('unknown', raw);
  }
}
