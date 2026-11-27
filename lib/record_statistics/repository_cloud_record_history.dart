import 'package:life_pilot/utils/repository_session_reads.dart';
import 'package:life_pilot/utils/value_parser.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CloudRecordHistoryWindow {
  const CloudRecordHistoryWindow({
    required this.rows,
    required this.total,
    required this.nextBefore,
    required this.nextDate,
  });

  final List<Map<String, dynamic>> rows;
  final num total;
  final DateTime nextBefore;
  final DateTime? nextDate;
}

/// Reads rows, total and the next history cursor in one database response.
class RepositoryCloudRecordHistory {
  String _group(String kind) => 'ledger-history-window:$kind';

  void invalidate(SupabaseClient client, {required String kind}) =>
      RepositorySessionReads(client).invalidate(_group(kind));

  Future<CloudRecordHistoryWindow> window(
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
    if (token == null) throw StateError('Authentication required');
    if (!until.isAfter(from) ||
        until.difference(from) > const Duration(days: 36525)) {
      throw ArgumentError('Invalid ledger history window');
    }
    final boundary = from.toUtc().toIso8601String();
    final upper = until.toUtc().toIso8601String();
    final result = await RepositorySessionReads(client).read(
      _group(kind),
      (kind, accountId, type, boundary, upper, includeReserved, includeLatest),
      () => client.rpc(
        'get_my_ledger_history_window_v2',
        params: {
          'p_kind': kind,
          'p_account_id': accountId,
          'p_type': type,
          'p_from': boundary,
          'p_until': upper,
          'p_include_reserved': includeReserved,
          'p_include_latest': includeLatest,
        },
      ),
    );
    if (client.auth.currentSession?.accessToken != token) {
      throw StateError('Ledger history account changed');
    }
    if (result is! Map || result['rows'] is! List) {
      throw const FormatException('Invalid ledger history window');
    }
    final rows = result['rows'] as List;
    return CloudRecordHistoryWindow(
      rows: List<Map<String, dynamic>>.from(rows),
      total: parseNumValue(result['total']),
      nextBefore:
          tryParseDateTimeValue(result['next_before'], toLocal: true) ?? from,
      nextDate: tryParseDateTimeValue(result['next_date'], toLocal: true),
    );
  }
}
