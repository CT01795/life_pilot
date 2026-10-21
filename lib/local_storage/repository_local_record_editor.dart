import 'package:life_pilot/local_storage/local_data_store.dart';

/// Shared read/merge/write flow for existing local records.
/// Callers build domain-specific fields; storage still enforces write access
/// and invalidates its caches. This is not a concurrent/atomic merge.
class RepositoryLocalRecordEditor {
  final LocalDataStore _store;
  RepositoryLocalRecordEditor({LocalDataStore? store})
    : _store = store ?? LocalDataStore.instance;

  Future<void> updateFields({
    required String owner,
    required String resource,
    required String id,
    required Map<String, Object?> fields,
    required String notFoundMessage,
  }) async {
    final row = await _store.readOnlyRow(
      owner: owner,
      resource: resource,
      id: id,
    );
    if (row == null) throw StateError(notFoundMessage);
    await _store.put(
      owner: owner,
      resource: resource,
      id: id,
      data: {...row, ...fields},
      syncState: LocalSyncState.modifiedLocally,
    );
  }
}
