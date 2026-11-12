import 'package:supabase_flutter/supabase_flutter.dart';

/// Resolves the ledger account linked to a calendar/recommendation event.
///
/// The database owns the direct-ID and detail-link rules so the App needs one
/// bounded request instead of downloading intermediate rows.
class RepositoryLedgerAccountLookup {
  const RepositoryLedgerAccountLookup(this.client);

  final SupabaseClient client;

  Future<Map<String, dynamic>?> find({
    required String kind,
    required String eventId,
    required String expectedEmail,
  }) async {
    final result = await client.rpc(
      'get_my_ledger_account_by_event',
      params: {
        'p_kind': kind,
        'p_event_id': eventId,
        'p_expected_email': expectedEmail,
      },
    );
    if (result == null) return null;
    if (result is! Map) {
      throw const FormatException('Invalid linked ledger account');
    }
    return Map<String, dynamic>.unmodifiable(Map<String, dynamic>.from(result));
  }

  Future<Map<String, dynamic>> entryDefaults({
    required String expectedEmail,
    String? accountingAccountId,
    String? pointAccountId,
  }) async {
    final result = await client.rpc(
      'get_my_ledger_entry_defaults',
      params: {
        'p_expected_email': expectedEmail,
        'p_accounting_account_id': accountingAccountId,
        'p_point_account_id': pointAccountId,
      },
    );
    if (result is! Map) {
      throw const FormatException('Invalid ledger entry defaults');
    }
    return Map<String, dynamic>.unmodifiable(Map<String, dynamic>.from(result));
  }
}
