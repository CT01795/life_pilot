import 'package:life_pilot/utils/repository_optional_json_rpc.dart';
import 'package:life_pilot/utils/supabase.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _CatalogState {
  Object? scope;
  int revision = 0;
  final pending = <bool, Future<List<dynamic>>>{};
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
    state.values.clear();
  }

  Future<List<dynamic>> read({required bool vendor, bool displayOnly = false}) {
    final state = _states[client] ??= _CatalogState();
    final scope = _scope;
    if (state.scope != scope) {
      invalidate();
      state.scope = scope;
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
    final revision = state.revision;
    late Future<List<dynamic>> request;
    request =
        Future<List<dynamic>>.sync(() async {
          final result = await RepositoryOptionalJsonRpc(client).read(
            'get_pricing_catalog',
            params: {'p_vendor': vendor},
            rememberMissing: false,
          );
          final rows = result == null
              ? await client.rpc(
                      vendor
                          ? 'get_vendor_pricing_versions'
                          : 'get_subscription_pricing_versions',
                    )
                    as List
              : result['versions'] as List;
          if (_scope != scope || state.revision != revision) {
            throw StateError('Pricing request scope changed');
          }
          final frozen = List<dynamic>.unmodifiable(
            rows.map(
              (row) => Map<String, dynamic>.unmodifiable(
                Map<String, dynamic>.from(row as Map),
              ),
            ),
          );
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
