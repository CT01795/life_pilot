import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Remembers only a successful initialization for the latest authenticated
/// session. Failures/missing RPCs can retry; account switches cannot reuse it.
class RepositoryVendorInitialization {
  RepositoryVendorInitialization(this.client);
  final SupabaseClient client;
  Object? _scope;
  Future<void>? _ready;

  Future<void> ensure(Object? scope) {
    if (scope != null && _scope == scope && _ready != null) return _ready!;
    final completion = Completer<void>();
    final request = completion.future;
    if (scope != null) {
      _scope = scope;
      _ready = request;
    }
    void forget() {
      if (identical(_ready, request)) {
        _scope = null;
        _ready = null;
      }
    }

    unawaited(
      _initialize().then<void>(
        (_) {
          completion.complete();
        },
        onError: (Object error, StackTrace stack) {
          forget();
          completion.completeError(error, stack);
        },
      ),
    );
    return request;
  }

  Future<void> _initialize() async {
    await client.rpc('ensure_my_vendor_account');
  }
}
