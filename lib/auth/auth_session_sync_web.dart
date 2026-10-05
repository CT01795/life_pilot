import 'dart:async';
import 'dart:convert';
// ignore: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;

/// Emits the account persisted by another browser tab whenever its Supabase
/// session changes. A null account means that the other tab signed out.
Stream<String?> get externalAuthAccountChanges => html.window.onStorage
    .where((event) => event.key?.contains('auth-token') == true)
    .map((event) => _sessionEmail(event.newValue));

String? _sessionEmail(String? rawValue) {
  if (rawValue == null || rawValue.isEmpty) return null;
  try {
    final decoded = jsonDecode(rawValue);
    if (decoded is! Map) return '';
    final session = Map<String, dynamic>.from(decoded);
    final user = session['user'];
    if (user is Map) return user['email']?.toString().toLowerCase();
  } on FormatException {
    // A malformed/transitional value is not a sign-out event. Emit an empty
    // marker so the controller can ignore it rather than clearing the page.
    return '';
  }
  return '';
}
