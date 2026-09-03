import 'package:sembast/sembast.dart';
import 'package:life_pilot/local_storage/local_database_factory.dart';

enum DataStorageLocation { cloud, local }

enum LocalSyncState { localOnly, movedFromCloud, modifiedLocally }

class LocalDataStore {
  LocalDataStore._();

  static final LocalDataStore instance = LocalDataStore._();
  static final _records = stringMapStoreFactory.store('records');
  static final _settings = stringMapStoreFactory.store('settings');
  Future<Database>? _databaseFuture;

  Future<Database> get _db async {
    final opening = _databaseFuture ??= openLifePilotLocalDatabase();
    try {
      return await opening.timeout(const Duration(seconds: 10));
    } catch (_) {
      if (identical(_databaseFuture, opening)) _databaseFuture = null;
      rethrow;
    }
  }

  String _recordKey(String owner, String resource, String id) =>
      '${owner.toLowerCase()}::$resource::$id';

  Future<DataStorageLocation?> preferredLocation(String owner) async {
    final value = await _settings
        .record('${owner.toLowerCase()}::preferred_location')
        .get(await _db);
    final name = value?['value']?.toString();
    for (final location in DataStorageLocation.values) {
      if (location.name == name) return location;
    }
    return null;
  }

  Future<void> setPreferredLocation(
    String owner,
    DataStorageLocation location,
  ) async {
    await _settings.record('${owner.toLowerCase()}::preferred_location').put(
      await _db,
      {'value': location.name, 'updated_at': DateTime.now().toIso8601String()},
    );
  }

  Future<void> put({
    required String owner,
    required String resource,
    required String id,
    required Map<String, Object?> data,
    LocalSyncState syncState = LocalSyncState.localOnly,
    String? originalCloudId,
  }) async {
    await _records.record(_recordKey(owner, resource, id)).put(await _db, {
      'owner': owner.toLowerCase(),
      'resource': resource,
      'id': id,
      'data': data,
      'sync_state': syncState.name,
      'original_cloud_id': originalCloudId,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  Future<List<Map<String, dynamic>>> list({
    required String owner,
    required String resource,
  }) async {
    final snapshots = await _records
        .find(
          await _db,
          finder: Finder(
            filter: Filter.and([
              Filter.equals('owner', owner.toLowerCase()),
              Filter.equals('resource', resource),
            ]),
          ),
        )
        .timeout(const Duration(seconds: 10));
    return snapshots
        .map((snapshot) => Map<String, dynamic>.from(
              snapshot.value['data']! as Map,
            ))
        .toList();
  }

  Future<void> delete({
    required String owner,
    required String resource,
    required String id,
  }) async {
    await _records.record(_recordKey(owner, resource, id)).delete(await _db);
  }

  Future<void> deleteMany({
    required String owner,
    required Iterable<({String resource, String id})> records,
  }) async {
    final database = await _db;
    await database.transaction((transaction) async {
      for (final record in records) {
        await _records
            .record(_recordKey(owner, record.resource, record.id))
            .delete(transaction);
      }
    });
  }

  Future<void> deleteAllRecords({required String owner}) async {
    await _records.delete(
      await _db,
      finder: Finder(
        filter: Filter.equals('owner', owner.toLowerCase()),
      ),
    );
  }

  Future<bool> contains({
    required String owner,
    required String resource,
    required String id,
  }) async {
    return await _records
            .record(_recordKey(owner, resource, id))
            .get(await _db) !=
        null;
  }

  Future<int> count({
    required String owner,
    required String resource,
  }) async {
    return _records.count(
      await _db,
      filter: Filter.and([
        Filter.equals('owner', owner.toLowerCase()),
        Filter.equals('resource', resource),
      ]),
    );
  }

  Future<Map<String, int>> countByResources({
    required String owner,
    required Iterable<String> resources,
  }) async {
    final requested = resources.toSet();
    final counts = <String, int>{for (final resource in requested) resource: 0};
    if (requested.isEmpty) return counts;

    final snapshots = await _records.find(
      await _db,
      finder: Finder(
        filter: Filter.equals('owner', owner.toLowerCase()),
      ),
    );
    for (final snapshot in snapshots) {
      final resource = snapshot.value['resource']?.toString();
      if (resource != null && requested.contains(resource)) {
        counts[resource] = counts[resource]! + 1;
      }
    }
    return counts;
  }
}
