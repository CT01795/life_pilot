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
  final Map<String, Future<List<Map<String, dynamic>>>> _listCache = {};
  final Map<String, bool> _createAllowed = {};

  void setCreateAllowed(String owner, bool allowed) {
    _createAllowed[owner.toLowerCase()] = allowed;
  }

  void clearCreatePermission(String owner) {
    _createAllowed.remove(owner.toLowerCase());
  }

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

  String _resourceCacheKey(String owner, String resource) =>
      '${owner.toLowerCase()}::$resource';

  String _countKey(String owner, String resource) =>
      '${owner.toLowerCase()}::record_count::$resource';

  Future<void> _setCount(
    DatabaseClient database,
    String owner,
    String resource,
    int value,
  ) =>
      _settings.record(_countKey(owner, resource)).put(database, {
        'value': value < 0 ? 0 : value,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });

  Future<int?> _cachedCount(
    DatabaseClient database,
    String owner,
    String resource,
  ) async {
    final row =
        await _settings.record(_countKey(owner, resource)).get(database);
    return (row?['value'] as num?)?.toInt();
  }

  Future<void> _adjustCount(
    DatabaseClient database,
    String owner,
    String resource,
    int delta,
  ) async {
    final cached = await _cachedCount(database, owner, resource);
    if (cached == null) return;
    await _setCount(database, owner, resource, cached + delta);
  }

  void _invalidateResource(String owner, String resource) {
    _listCache.remove(_resourceCacheKey(owner, resource));
  }

  void _invalidateOwner(String owner) {
    final prefix = '${owner.toLowerCase()}::';
    _listCache.removeWhere((key, _) => key.startsWith(prefix));
  }

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
    final database = await _db;
    await database.transaction((transaction) async {
      final record = _records.record(_recordKey(owner, resource, id));
      final existed = await record.exists(transaction);
      if (!existed && _createAllowed[owner.toLowerCase()] == false) {
        throw StateError('local_subscription_expired_read_only');
      }
      await record.put(transaction, {
        'owner': owner.toLowerCase(),
        'resource': resource,
        'id': id,
        'data': data,
        'sync_state': syncState.name,
        'original_cloud_id': originalCloudId,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });
      if (!existed) await _adjustCount(transaction, owner, resource, 1);
    });
    _invalidateResource(owner, resource);
  }

  Future<List<Map<String, dynamic>>> list({
    required String owner,
    required String resource,
  }) async {
    final cacheKey = _resourceCacheKey(owner, resource);
    final request = _listCache[cacheKey] ??= _loadList(owner, resource);
    try {
      final rows = await request;
      return rows.map(Map<String, dynamic>.from).toList();
    } catch (_) {
      if (identical(_listCache[cacheKey], request)) {
        _listCache.remove(cacheKey);
      }
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> _loadList(
    String owner,
    String resource,
  ) async {
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
        .toList(growable: false);
  }

  Future<void> delete({
    required String owner,
    required String resource,
    required String id,
  }) async {
    final database = await _db;
    await database.transaction((transaction) async {
      final record = _records.record(_recordKey(owner, resource, id));
      final existed = await record.exists(transaction);
      await record.delete(transaction);
      if (existed) await _adjustCount(transaction, owner, resource, -1);
    });
    _invalidateResource(owner, resource);
  }

  Future<void> deleteMany({
    required String owner,
    required Iterable<({String resource, String id})> records,
  }) async {
    final recordList = records.toList(growable: false);
    final database = await _db;
    await database.transaction((transaction) async {
      final deletedByResource = <String, int>{};
      for (final record in recordList) {
        final stored =
            _records.record(_recordKey(owner, record.resource, record.id));
        if (await stored.exists(transaction)) {
          await stored.delete(transaction);
          deletedByResource.update(record.resource, (value) => value + 1,
              ifAbsent: () => 1);
        }
      }
      for (final entry in deletedByResource.entries) {
        await _adjustCount(transaction, owner, entry.key, -entry.value);
      }
    });
    for (final resource
        in recordList.map((record) => record.resource).toSet()) {
      _invalidateResource(owner, resource);
    }
  }

  Future<void> deleteAllRecords({required String owner}) async {
    final database = await _db;
    await database.transaction((transaction) async {
      await _records.delete(
        transaction,
        finder: Finder(
          filter: Filter.equals('owner', owner.toLowerCase()),
        ),
      );
      await _settings.delete(
        transaction,
        finder: Finder(
          filter: Filter.custom((record) => record.key
              .toString()
              .startsWith('${owner.toLowerCase()}::record_count::')),
        ),
      );
    });
    _invalidateOwner(owner);
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
    final database = await _db;
    final cached = await _cachedCount(database, owner, resource);
    if (cached != null) return cached;

    return database.transaction((transaction) async {
      final existing = await _cachedCount(transaction, owner, resource);
      if (existing != null) return existing;
      final value = await _records.count(
        transaction,
        filter: Filter.and([
          Filter.equals('owner', owner.toLowerCase()),
          Filter.equals('resource', resource),
        ]),
      );
      await _setCount(transaction, owner, resource, value);
      return value;
    });
  }

  Future<Map<String, int>> countByResources({
    required String owner,
    required Iterable<String> resources,
  }) async {
    final requested = resources.toSet().toList(growable: false);
    if (requested.isEmpty) return const {};
    final values = await Future.wait(
      requested.map((resource) => count(owner: owner, resource: resource)),
    );
    return {
      for (var index = 0; index < requested.length; index++)
        requested[index]: values[index],
    };
  }
}
