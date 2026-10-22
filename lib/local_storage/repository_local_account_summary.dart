import 'package:life_pilot/local_storage/local_data_store.dart';
import 'package:life_pilot/utils/model_local_account_list.dart';
import 'package:life_pilot/utils/const.dart';
import 'package:life_pilot/utils/value_parser.dart';

/// Exact account lookup; totals reuse the account-list projection's rules.
/// Unchanged detail snapshots reuse their total; no account-list read needed.
class RepositoryLocalAccountSummary {
  RepositoryLocalAccountSummary({LocalDataStore? store})
    : _store = store ?? LocalDataStore.instance;
  final LocalDataStore _store;

  Future<({Map<String, dynamic> row, num total})?> read({
    required String owner,
    required String accountId,
    required bool points,
  }) async {
    if (accountId.isEmpty) return null;
    final row = await _store.readOnlyRow(
      owner: owner,
      resource: points
          ? TableNames.pointRecordAccount
          : TableNames.accountingAccount,
      id: accountId,
    );
    if (row == null ||
        row[Fields.isValid] != true ||
        parseStringValue(row[Fields.id]) != accountId) {
      return null;
    }
    final details = await _store.readOnlyRows(
      owner: owner,
      resource: points
          ? TableNames.pointRecordDetail
          : TableNames.accountingDetail,
    );
    return (
      row: row,
      total: ModelLocalAccountList.totalForSnapshot(
        details: details,
        account: row,
        points: points,
      ),
    );
  }
}
