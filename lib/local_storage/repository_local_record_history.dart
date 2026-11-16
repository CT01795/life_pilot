import 'package:life_pilot/local_storage/local_data_store.dart';
import 'package:life_pilot/utils/model_local_record_page.dart';
import 'package:life_pilot/utils/record_row_utils.dart';

/// Read-only latest records and history metadata for accounting/point details.
/// Filtering/date policy remains in record_row_utils; no UI or auth state.
class RepositoryLocalRecordHistory {
  final LocalDataStore _store;
  static final _indexes =
      Expando<Map<(String, bool), ModelLocalRecordDateIndex>>();
  RepositoryLocalRecordHistory({LocalDataStore? store})
    : _store = store ?? LocalDataStore.instance;

  Future<List<RecordRow>> accountRows({
    required String owner,
    required String resource,
    required String accountId,
    required String type,
  }) => _store.ledgerScopeRows(
    owner: owner,
    resource: resource,
    accountId: accountId,
    type: type,
  );

  Future<ModelLocalRecordPage> page({
    required String owner,
    required String resource,
    required String accountId,
    required String type,
    required bool points,
    required DateTime from,
    required DateTime to,
    required bool includeLatestFallback,
    required bool includeReservedRecords,
  }) async {
    final rows = await accountRows(
      owner: owner,
      resource: resource,
      accountId: accountId,
      type: type,
    );
    // A write replaces the immutable list, invalidating its derived index.
    final indexes = _indexes[rows] ??= {};
    final key = (type.toLowerCase(), points);
    final index = indexes.putIfAbsent(
      key,
      () => ModelLocalRecordDateIndex(
        rows,
        accountId: accountId,
        type: type,
        points: points,
      ),
    );
    return index.page(
      from: from,
      to: to,
      includeLatestFallback: includeLatestFallback,
      includeReservedRecords: includeReservedRecords,
    );
  }

  Future<RecordRow?> latestRecord({
    required String owner,
    required String resource,
    required String accountId,
    required String type,
  }) async {
    final rows = await accountRows(
      owner: owner,
      resource: resource,
      accountId: accountId,
      type: type,
    );
    RecordRow? latest;
    for (final row in rows) {
      if (latest == null || compareRecordRowsNewestFirst(row, latest) < 0) {
        latest = row;
      }
    }
    return latest;
  }
}
