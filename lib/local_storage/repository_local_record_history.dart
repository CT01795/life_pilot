import 'package:life_pilot/local_storage/local_data_store.dart';
import 'package:life_pilot/utils/record_row_utils.dart';

/// Read-only latest records and history metadata for accounting/point details.
/// Filtering/date policy remains in record_row_utils; no UI or auth state.
class RepositoryLocalRecordHistory {
  final LocalDataStore _store;
  RepositoryLocalRecordHistory({LocalDataStore? store})
    : _store = store ?? LocalDataStore.instance;

  Future<RecordRow?> latestRecord({
    required String owner,
    required String resource,
    required String accountId,
    required String type,
  }) async => latestRecordRowForAccountAndType(
    await _store.readOnlyRows(owner: owner, resource: resource),
    accountId: accountId,
    type: type,
  );

  Future<Iterable<RecordRow>> _matchingRows({
    required String owner,
    required String resource,
    required String accountId,
    required String type,
  }) async {
    final rows = await _store.readOnlyRows(owner: owner, resource: resource);
    return rows.where(
      (row) =>
          recordRowMatchesAccountAndType(row, accountId: accountId, type: type),
    );
  }

  Future<bool> hasRecordsBefore({
    required String owner,
    required String resource,
    required String accountId,
    required String type,
    required DateTime before,
  }) async => hasRecordRowBefore(
    await _matchingRows(
      owner: owner,
      resource: resource,
      accountId: accountId,
      type: type,
    ),
    before,
  );

  Future<DateTime?> latestRecordDateBefore({
    required String owner,
    required String resource,
    required String accountId,
    required String type,
    required DateTime before,
  }) async => latestRecordRowDateBefore(
    await _matchingRows(
      owner: owner,
      resource: resource,
      accountId: accountId,
      type: type,
    ),
    before,
  );
}
