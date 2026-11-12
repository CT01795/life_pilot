import 'package:life_pilot/local_storage/local_data_store.dart';
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
    final currency = points ? null : parseStringValue(row['main_currency']);
    final totals = await _store.ledgerTotals(
      owner: owner,
      resource: points
          ? TableNames.pointRecordDetail
          : TableNames.accountingDetail,
      accounts: [(accountId: accountId, currency: currency)],
    );
    return (row: row, total: totals[(accountId, currency)] ?? 0);
  }
}
