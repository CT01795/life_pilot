import 'package:life_pilot/accounting/repository_ledger_account_lookup.dart';
import 'package:life_pilot/local_storage/local_data_store.dart';
import 'package:life_pilot/local_storage/repository_local_record_history.dart';
import 'package:life_pilot/utils/const.dart';
import 'package:life_pilot/utils/model_record_entry_defaults.dart';
import 'package:life_pilot/utils/supabase.dart';

class ServiceLedgerEntryDefaults {
  Future<({(bool, String)? accounting, (bool, String)? points})> load({
    required String expectedEmail,
    String? accountingAccountId,
    String? pointAccountId,
  }) async {
    final owner = supabase.auth.currentUser?.email?.trim().toLowerCase();
    if (owner == null || owner != expectedEmail.trim().toLowerCase()) {
      throw StateError('Ledger defaults account changed');
    }
    if (await LocalDataStore.instance.preferredLocation(owner) ==
        DataStorageLocation.local) {
      final history = RepositoryLocalRecordHistory();
      final rows = await Future.wait<Map<String, dynamic>?>([
        accountingAccountId == null
            ? Future.value()
            : history.latestRecord(
                owner: owner,
                resource: TableNames.accountingDetail,
                accountId: accountingAccountId,
                type: 'balance',
              ),
        pointAccountId == null
            ? Future.value()
            : history.latestRecord(
                owner: owner,
                resource: TableNames.pointRecordDetail,
                accountId: pointAccountId,
                type: 'points',
              ),
      ]);
      return (
        accounting: ModelRecordEntryDefaults.accountingDirectionAndCategory(
          rows[0],
        ),
        points: ModelRecordEntryDefaults.pointDirectionAndCategory(rows[1]),
      );
    }
    final result = await RepositoryLedgerAccountLookup(supabase).entryDefaults(
      expectedEmail: expectedEmail,
      accountingAccountId: accountingAccountId,
      pointAccountId: pointAccountId,
    );
    final accounting = result['accounting'];
    final points = result['points'];
    return (
      accounting: accounting is Map
          ? ModelRecordEntryDefaults.accountingDirectionAndCategory(
              Map<String, dynamic>.from(accounting),
            )
          : null,
      points: points is Map
          ? ModelRecordEntryDefaults.pointDirectionAndCategory(
              Map<String, dynamic>.from(points),
            )
          : null,
    );
  }
}
