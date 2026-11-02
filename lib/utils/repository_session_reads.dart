import 'package:life_pilot/utils/in_flight_read_pool.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _ReadGroup {
  int revision = 0;
  final pool = InFlightReadPool<Object, Object?>();
  void invalidate() {
    revision++;
    pool.invalidate();
  }
}

class _SessionReads {
  Object? scope;
  final groups = <String, _ReadGroup>{};
}

/// Coalesces active reads only, never completed authorization/usage results.
/// The service owning a mutation must invalidate its group before and after it.
class RepositorySessionReads {
  const RepositorySessionReads(this.client);
  final SupabaseClient client;
  static final _states = Expando<_SessionReads>();

  Object? get _scope {
    final session = client.auth.currentSession;
    return session == null ? null : (session.user.id, session.accessToken);
  }

  _SessionReads _state() {
    final state = _states[client] ??= _SessionReads();
    final scope = _scope;
    if (state.scope != scope) {
      for (final group in state.groups.values) {
        group.invalidate();
      }
      state.scope = scope;
    }
    return state;
  }

  void invalidate(String group) => _state().groups[group]?.invalidate();

  Future<T> read<T>(
    String group,
    Object key,
    Future<T> Function() fetch, {
    Duration? timeout = const Duration(seconds: 30),
  }) async {
    final scope = _scope;
    if (scope == null) throw StateError('Authentication required');
    final state = _state();
    final reads = state.groups.putIfAbsent(group, _ReadGroup.new);
    final revision = reads.revision;
    bool current() => _scope == scope && reads.revision == revision;
    final result = await reads.pool.read((scope, key), () async {
      if (!current()) throw StateError('Read scope changed');
      final value = await fetch();
      if (!current()) throw StateError('Read scope changed');
      return value;
    }, timeout: timeout);
    if (!current()) throw StateError('Read scope changed');
    return result as T;
  }
}
