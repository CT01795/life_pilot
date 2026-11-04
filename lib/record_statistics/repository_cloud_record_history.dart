import 'package:life_pilot/utils/record_row_utils.dart';
import 'package:life_pilot/utils/repository_session_reads.dart';
import 'package:life_pilot/utils/repository_optional_json_rpc.dart';
import 'package:life_pilot/utils/value_parser.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Reuses a recent existence probe once, for the exact same history boundary.
class RepositoryCloudRecordHistory {
  ({Object key, DateTime date, DateTime readAt})? _hint;
  int _revision = 0;
  ({Object key, DateTime? date, DateTime readAt})? _windowHint;

  void invalidate() {
    _hint = null;
    _windowHint = null;
    _revision++;
  }

  Future<List<Map<String, dynamic>>?> window(
    SupabaseClient client, {
    required String table,
    required String kind,
    required String accountId,
    required String type,
    required DateTime from,
    required DateTime until,
    required bool includeReserved,
    bool includeLatest = false,
  }) async {
    final token = client.auth.currentSession?.accessToken;
    if (token == null ||
        !until.isAfter(from) ||
        until.difference(from) > const Duration(days: 100)) {
      return null;
    }
    final revision = _revision;
    final boundary = from.toUtc().toIso8601String();
    final upper = until.toUtc().toIso8601String();
    final result = await RepositorySessionReads(client).read(
      'ledger-history-window',
      (
        kind,
        accountId,
        type,
        boundary,
        upper,
        includeReserved,
        includeLatest,
        revision,
      ),
      () => RepositoryOptionalJsonRpc(client).read(
        includeLatest
            ? 'get_my_ledger_history_window_v2'
            : 'get_my_ledger_history_window',
        params: {
          'p_kind': kind,
          'p_account_id': accountId,
          'p_type': type,
          'p_from': boundary,
          'p_until': upper,
          'p_include_reserved': includeReserved,
          if (includeLatest) 'p_include_latest': true,
        },
      ),
    );
    if (client.auth.currentSession?.accessToken != token) {
      throw StateError('Ledger history account changed');
    }
    final rows = result?['rows'];
    if (rows is! List) return null;
    if (revision == _revision) {
      final nextBoundary =
          tryParseDateTimeValue(
            result?['next_before'],
          )?.toUtc().toIso8601String() ??
          boundary;
      _windowHint = (
        key: (client, token, table, accountId, type, nextBoundary),
        date: tryParseDateTimeValue(result?['next_date'], toLocal: true),
        readAt: DateTime.now(),
      );
    }
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<DateTime?> latestBefore(
    SupabaseClient client, {
    required String table,
    required String accountId,
    required String type,
    required DateTime before,
    bool rememberForNextPage = false,
  }) async {
    final token = client.auth.currentSession?.accessToken;
    final revision = _revision;
    final boundary = before.toUtc().toIso8601String();
    final key = (client, token, table, accountId, type, boundary);
    final window = _windowHint;
    _windowHint = null;
    if (rememberForNextPage &&
        window != null &&
        window.key == key &&
        DateTime.now().difference(window.readAt) <
            const Duration(seconds: 15)) {
      final date = window.date;
      if (date != null) _hint = (key: key, date: date, readAt: window.readAt);
      return date;
    }
    final hint = _hint;
    _hint = null;
    if (!rememberForNextPage &&
        token != null &&
        hint?.key == key &&
        DateTime.now().difference(hint!.readAt) < const Duration(seconds: 15)) {
      return hint.date;
    }
    Future<DateTime?> fetch() async {
      final rows = await client
          .from(table)
          .select('date')
          .eq('account_id', accountId)
          .ilike('type', type)
          .lt('date', boundary)
          .neq('primary_category', reservedRecordCategory)
          .order('date', ascending: false)
          .limit(1);
      return rows.isEmpty
          ? null
          : tryParseDateTimeValue(rows.first['date'], toLocal: true);
    }

    final date = token == null
        ? await fetch()
        : await RepositorySessionReads(client).read('ledger-history-probe', (
            table,
            accountId,
            type,
            boundary,
            revision,
          ), fetch);
    if (rememberForNextPage &&
        date != null &&
        token != null &&
        revision == _revision &&
        client.auth.currentSession?.accessToken == token) {
      _hint = (key: key, date: date, readAt: DateTime.now());
    }
    return date;
  }
}
