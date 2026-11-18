import 'package:life_pilot/accounting/model_ledger_account_option.dart';
import 'package:life_pilot/local_storage/local_data_store.dart';
import 'package:life_pilot/utils/const.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Reads only the account identity required by dashboard selectors.
class RepositoryLedgerAccountOptions {
  RepositoryLedgerAccountOptions(this._client);

  final SupabaseClient _client;

  Future<ModelLedgerAccountOptionPage> readPage({
    required String kind,
    required String expectedEmail,
    String search = '',
    Map<String, dynamic>? cursor,
    String? selectedId,
    int limit = 20,
  }) async {
    if (kind != 'accounting' && kind != 'points') {
      throw ArgumentError.value(kind, 'kind');
    }
    if (limit < 1 || limit > 50) {
      throw RangeError.range(limit, 1, 50, 'limit');
    }
    final owner = _client.auth.currentUser?.email?.trim().toLowerCase();
    if (owner == null || owner != expectedEmail.trim().toLowerCase()) {
      throw StateError('Account option owner mismatch');
    }

    final location = await LocalDataStore.instance.preferredLocation(owner);
    if (location == DataStorageLocation.local) {
      final rows = await LocalDataStore.instance.readOnlyRows(
        owner: owner,
        resource: kind == 'accounting'
            ? TableNames.accountingAccount
            : TableNames.pointRecordAccount,
      );
      final normalizedSearch = search.trim().toLowerCase();
      final options = ModelLedgerAccountOption.selectLocal(
        rows.where(
          (row) =>
              normalizedSearch.isEmpty ||
              (row[Fields.account]?.toString().toLowerCase().contains(
                    normalizedSearch,
                  ) ??
                  false),
        ),
        projectLimit: rows.length,
      );
      final offset = int.tryParse(cursor?['offset']?.toString() ?? '') ?? 0;
      final page = options.skip(offset).take(limit).toList(growable: false);
      final selected = selectedId == null
          ? null
          : options.where((option) => option.id == selectedId).firstOrNull;
      final visible =
          cursor == null && selected != null && !page.contains(selected)
          ? [selected, ...page]
          : page;
      final nextOffset = offset + page.length;
      return ModelLedgerAccountOptionPage(
        rows: List.unmodifiable(visible),
        nextCursor: nextOffset < options.length ? {'offset': nextOffset} : null,
      );
    }

    final response = await _client.rpc(
      'get_my_dashboard_ledger_account_options',
      params: {
        'p_kind': kind,
        'p_search': search.trim(),
        'p_cursor': cursor,
        'p_selected_id': selectedId,
        'p_limit': limit,
      },
    );
    if (response is! Map) {
      throw const FormatException('Invalid ledger account options');
    }
    return ModelLedgerAccountOptionPage.fromJson(
      Map<String, dynamic>.from(response),
    );
  }
}
