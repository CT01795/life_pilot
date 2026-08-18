import 'dart:async';
// ignore: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;

/// Emits when another browser tab removes the persisted Supabase session.
Stream<void> get externalSignedOutEvents => html.window.onStorage
    .where((event) =>
        event.newValue == null &&
        (event.key == null || event.key!.contains('auth-token')))
    .map((_) {});
