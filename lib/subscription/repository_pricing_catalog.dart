import 'package:life_pilot/utils/supabase.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _CatalogState {
  Object? scope;
  int revision = 0;
  final readRevisions = <bool, int>{};
  final pending = <bool, Future<List<dynamic>>>{};
  final queued = <bool, Future<List<dynamic>>>{};
  final values = <bool, ({DateTime expires, List<dynamic> rows})>{};
}

/// Completed results are reused only for display, never quota/write decisions.
class RepositoryPricingCatalog {
  RepositoryPricingCatalog({SupabaseClient? client, DateTime Function()? now})
    : client = client ?? supabase,
      _now = now ?? DateTime.now;
  final SupabaseClient client;
  final DateTime Function() _now;
  static final _states = Expando<_CatalogState>();
  Object? get _scope {
    final user = client.auth.currentUser;
    return user == null
        ? null
        : (user.id, client.auth.currentSession?.accessToken);
  }

  void invalidate() {
    final state = _states[client];
    if (state == null) return;
    state.revision++;
    state.pending.clear();
    state.queued.clear();
    state.values.clear();
  }

  List<dynamic>? peek({required bool vendor}) {
    final state = _states[client];
    final scope = _scope;
    if (state == null || scope == null || state.scope != scope) return null;
    final cached = state.values[vendor];
    if (cached == null || !_now().isBefore(cached.expires)) return null;
    return cached.rows;
  }

  /// Seeds display-only catalog data returned by another combined RPC.
  /// Pricing writes and quota enforcement never rely on this snapshot.
  void seed({
    required bool vendor,
    required Iterable<Object?> rows,
    Duration ttl = const Duration(minutes: 5),
  }) {
    final scope = _scope;
    if (scope == null) return;
    final state = _states[client] ??= _CatalogState();
    if (state.scope != scope) {
      invalidate();
      state.scope = scope;
    }
    state.values[vendor] = (expires: _now().add(ttl), rows: _freeze(rows));
  }

  List<dynamic> _freeze(Iterable<Object?> rows) => List<dynamic>.unmodifiable(
    rows.map(
      (row) => Map<String, dynamic>.unmodifiable(
        Map<String, dynamic>.from(row as Map),
      ),
    ),
  );

  Future<List<dynamic>> read({
    required bool vendor,
    bool displayOnly = false,
    bool force = false,
  }) {
    final state = _states[client] ??= _CatalogState();
    final scope = _scope;
    if (state.scope != scope) {
      invalidate();
      state.scope = scope;
    }
    final queued = state.queued[vendor];
    if (queued != null) return queued;
    if (force) {
      state.values.remove(vendor);
      state.readRevisions.update(
        vendor,
        (value) => value + 1,
        ifAbsent: () => 1,
      );
      final active = state.pending[vendor];
      if (active != null) {
        final revision = state.revision;
        Future<List<dynamic>> followUp() async {
          try {
            await active;
          } catch (_) {
            // A forced read must still run after an obsolete or failed read.
          }
          if (_scope != scope || state.revision != revision) {
            throw StateError('Pricing request scope changed');
          }
          state.queued.remove(vendor);
          return _readCatalog(state, scope, vendor);
        }

        return state.queued[vendor] = followUp();
      }
    }
    final cached = state.values[vendor];
    if (displayOnly &&
        scope != null &&
        cached != null &&
        _now().isBefore(cached.expires)) {
      return Future.value(cached.rows);
    }
    final active = state.pending[vendor];
    if (active != null) return active;
    return _readCatalog(state, scope, vendor);
  }

  Future<List<dynamic>> _readCatalog(
    _CatalogState state,
    Object? scope,
    bool vendor,
  ) {
    final revision = state.revision;
    final readRevision = state.readRevisions[vendor];
    late Future<List<dynamic>> request;
    request =
        Future<List<dynamic>>.sync(() async {
          final result = await client
              .rpc('get_pricing_catalog', params: {'p_vendor': vendor})
              .timeout(const Duration(seconds: 30));
          if (_scope != scope ||
              state.revision != revision ||
              state.readRevisions[vendor] != readRevision) {
            throw StateError('Pricing request scope changed');
          }
          if (result is! Map || result['versions'] is! List) {
            throw const FormatException('Invalid pricing catalog');
          }
          final rows = result['versions'] as List;
          final frozen = _freeze(rows);
          if (scope != null) {
            state.values[vendor] = (
              expires: _now().add(const Duration(seconds: 30)),
              rows: frozen,
            );
          }
          return frozen;
        }).whenComplete(() {
          if (identical(state.pending[vendor], request)) {
            state.pending.remove(vendor);
          }
        });
    state.pending[vendor] = request;
    return request;
  }

  Future<void> save({
    required bool vendor,
    required Map<String, dynamic> payload,
    String? versionId,
  }) async {
    invalidate();
    try {
      await client.rpc(
        'admin_save_pricing_version',
        params: {
          'p_vendor': vendor,
          'p_payload': payload,
          'p_version_id': versionId,
        },
      );
    } finally {
      invalidate();
    }
  }
}
