import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/calendar/model_calendar_sharing_failure.dart';

void main() {
  const rules = {
    'QUOTA_REACHED': 'quota',
    'RENEWAL_REQUIRED': 'quota',
    'DUPLICATE_INVITATION': 'duplicate',
    'ACCOUNT_NOT_FOUND': 'account_not_found',
    'INVALID EMAIL': 'invalid_email',
    'CANNOT INVITE YOURSELF': 'self_invite',
    'NO OWNED EVENTS SELECTED': 'event_unavailable',
    'SHARED EVENT NOT FOUND': 'event_unavailable',
    'INVITATION CANNOT BE UPDATED': 'stale_invitation',
    'INVITATION NOT FOUND': 'stale_invitation',
  };
  for (final rule in rules.entries) {
    for (final field in ['message', 'details', 'hint', 'code']) {
      test('${rule.key} in $field preserves classification', () {
        final text = 'prefix ${rule.key.toLowerCase()} suffix';
        final error = CalendarSharingFailure.fromFields(
          message: field == 'message' ? text : null,
          details: field == 'details' ? text : null,
          hint: field == 'hint' ? text : null,
          code: field == 'code' ? text : null,
        );
        expect(error.code, rule.value);
        expect(error.details, isNull);
      });
    }
  }
  test('unknown fields retain original case and raw diagnostic order', () {
    final error = CalendarSharingFailure.fromFields(
      message: 'Database unavailable',
      details: {'reason': 'Retry'},
      hint: 'Later',
      code: 'XX000',
    );
    expect(error.code, 'unknown');
    expect(error.details, 'Database unavailable {reason: Retry} Later XX000');
  });
  test('missing fields do not become literal null strings', () {
    final error = CalendarSharingFailure.fromFields();
    expect(error.code, 'unknown');
    expect(error.details, '');
  });
  test(
    'quota classification retains priority over other matching patterns',
    () {
      final error = CalendarSharingFailure.fromFields(
        message: 'DUPLICATE_INVITATION',
        details: 'RENEWAL_REQUIRED',
      );
      expect(error.code, 'quota');
    },
  );
}
