import 'package:life_pilot/accounting/model_ledger_account_option.dart';
import 'package:life_pilot/local_storage/local_data_store.dart';
import 'package:life_pilot/utils/const.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Reads only the account identity required by dashboard selectors.
class RepositoryLedgerAccountOptions {
  RepositoryLedgerAccountOptions(this._client);

  final SupabaseClient _client;

  Future<List<ModelLedgerAccountOption>> read({
    required String kind,
    required String expectedEmail,
    int projectLimit = 2,
  }) async {
    if (kind != 'accounting' && kind != 'points') {
      throw ArgumentError.value(kind, 'kind');
    }
    if (projectLimit < 0) {
      throw ArgumentError.value(projectLimit, 'projectLimit');
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
      return ModelLedgerAccountOption.selectLocal(
        rows,
        projectLimit: projectLimit,
      );
    }

    final response = await _client.rpc(
      'get_my_ledger_account_options',
      params: {'p_kind': kind, 'p_project_limit': projectLimit},
    );
    if (response is! List) {
      throw const FormatException('Invalid ledger account options');
    }
    return List.unmodifiable(
      response.map(
        (row) => ModelLedgerAccountOption.fromRow(
          Map<String, dynamic>.from(row as Map),
        ),
      ),
    );
  }
}
