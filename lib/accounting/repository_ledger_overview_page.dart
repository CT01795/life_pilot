import 'package:supabase_flutter/supabase_flutter.dart';

class RepositoryLedgerOverviewPage {
  const RepositoryLedgerOverviewPage(this.client);
  final SupabaseClient client;

  Future<List<Map<String, dynamic>>> read({
    required String kind,
    required String expectedEmail,
    String? category,
    String? search,
    required int offset,
    required int limit,
  }) async {
    final result = await client.rpc(
      'list_my_ledger_overview_page',
      params: {
        'p_kind': kind,
        'p_expected_email': expectedEmail,
        'p_category': category,
        'p_search': search?.trim(),
        'p_offset': offset,
        'p_limit': limit,
      },
    );
    if (result is! List) throw const FormatException('Invalid ledger page');
    return result
        .map((item) {
          final row = Map<String, dynamic>.from(item as Map);
          final count = row['pending_count'];
          if (count is! int || count < 0) {
            throw const FormatException('Missing ledger proposal count');
          }
          return row;
        })
        .toList(growable: false);
  }
}
