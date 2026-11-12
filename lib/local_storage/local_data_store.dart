import 'package:sembast/sembast.dart';
import 'package:life_pilot/local_storage/local_database_factory.dart';
import 'package:life_pilot/utils/value_parser.dart';

enum DataStorageLocation { cloud, local }

enum LocalSyncState { localOnly, movedFromCloud, modifiedLocally }

class LocalDataStore {
  LocalDataStore._();

  /// Uses an isolated, already-open database without changing the singleton.
  LocalDataStore.withDatabase(Database database)
    : _databaseFuture = Future<Database>.value(database);

  static final LocalDataStore instance = LocalDataStore._();
  static final _records = stringMapStoreFactory.store('records');
  static final _settings = stringMapStoreFactory.store('settings');
  Future<Database>? _databaseFuture;
  final Map<String, Future<List<Map<String, dynamic>>>> _listCache = {};
  final _scopedLists = <String, (Object, Future<List<Map<String, dynamic>>>)>{};
  final Map<String, bool> _createAllowed = {};
  final Map<String, bool> _deleteAllowed = {};
  final Map<String, bool Function()> _writeChecks = {};

  void setWriteCheck(String owner, bool Function() check) {
    _writeChecks[owner.toLowerCase()] = check;
  }

  void setDeleteAllowed(String owner, bool allowed) {
    _deleteAllowed[owner.toLowerCase()] = allowed;
  }

  void _assertDeleteAllowed(String owner) {
    if (_deleteAllowed[owner.toLowerCase()] == false) {
      throw StateError('LIFE_PILOT_QUOTA_CONFIGURATION_MISSING');
    }
  }

  void setCreateAllowed(String owner, bool allowed) {
    _createAllowed[owner.toLowerCase()] = allowed;
  }

  void clearCreatePermission(String owner) {
    _createAllowed.remove(owner.toLowerCase());
    _deleteAllowed.remove(owner.toLowerCase());
    _writeChecks.remove(owner.toLowerCase());
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

  bool _isLedgerDetailResource(String resource) =>
      resource == 'accounting_detail' || resource == 'point_record_detail';

  num _ledgerValue(String resource, Object? value) =>
      resource == 'point_record_detail'
      ? parseIntValue(value)
      : parseNumValue(value);

  String? _ledgerTotalKey(String owner, String resource, Map? data) {
    if (!_isLedgerDetailResource(resource) || data == null) return null;
    final accountId = parseStringValue(data['account_id']);
    if (accountId.isEmpty) return null;
    final currency = resource == 'accounting_detail'
        ? parseStringValue(data['currency'])
        : '';
    return '${owner.toLowerCase()}::ledger_total::$resource::$accountId::$currency';
  }

  Future<void> _adjustLedgerTotal(
    DatabaseClient database,
    String owner,
    String resource,
    Map? data,
    num direction,
  ) async {
    final key = _ledgerTotalKey(owner, resource, data);
    if (key == null) return;
    final record = _settings.record(key);
    final cached = await record.get(database);
    final current = tryParseNumValue(cached?['value']);
    if (current == null) return;
    await record.put(database, {
      'value': current + _ledgerValue(resource, data?['value']) * direction,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  Future<void> _setCount(
    DatabaseClient database,
    String owner,
    String resource,
    int value,
  ) => _settings.record(_countKey(owner, resource)).put(database, {
    'value': value < 0 ? 0 : value,
    'updated_at': DateTime.now().toUtc().toIso8601String(),
  });

  Future<int?> _cachedCount(
    DatabaseClient database,
    String owner,
    String resource,
  ) async {
    final row = await _settings
        .record(_countKey(owner, resource))
        .get(database);
    return tryParseIntValue(row?['value']);
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
    _scopedLists.remove(_resourceCacheKey(owner, resource));
  }

  void _invalidateOwner(String owner) {
    final prefix = '${owner.toLowerCase()}::';
    _listCache.removeWhere((key, _) => key.startsWith(prefix));
    _scopedLists.removeWhere((key, _) => key.startsWith(prefix));
  }

  Future<DataStorageLocation?> preferredLocation(String owner) async {
    final value = await _settings
        .record('${owner.toLowerCase()}::preferred_location')
        .get(await _db);
    final name = parseOptionalStringValue(value?['value']);
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
    _assertDeleteAllowed(owner);
    final database = await _db;
    await database.transaction((transaction) async {
      final record = _records.record(_recordKey(owner, resource, id));
      final previous = await record.get(transaction);
      final existed = previous != null;
      final ownerKey = owner.toLowerCase();
      if (_createAllowed[ownerKey] == false ||
          _writeChecks[ownerKey]?.call() == false) {
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
      await _adjustLedgerTotal(
        transaction,
        owner,
        resource,
        previous?['data'] as Map?,
        -1,
      );
      await _adjustLedgerTotal(transaction, owner, resource, data, 1);
      if (!existed) await _adjustCount(transaction, owner, resource, 1);
    });
    _invalidateResource(owner, resource);
  }

  /// Reads one owner/resource-scoped key without loading the resource list.
  /// As with [readOnlyRows], nested values must be treated as read-only.
  Future<Map<String, dynamic>?> readOnlyRow({
    required String owner,
    required String resource,
    required String id,
  }) async {
    final snapshot = await _records
        .record(_recordKey(owner, resource, id))
        .get(await _db)
        .timeout(const Duration(seconds: 10));
    if (snapshot == null) return null;
    return Map<String, dynamic>.unmodifiable(snapshot['data']! as Map);
  }

  Future<List<Map<String, dynamic>>> list({
    required String owner,
    required String resource,
  }) async {
    final rows = await readOnlyRows(owner: owner, resource: resource);
    return rows.map(Map<String, dynamic>.from).toList();
  }

  /// Shares cached rows for query-only consumers. The list and row maps cannot
  /// be modified; nested field values must also be treated as read-only.
  Future<List<Map<String, dynamic>>> readOnlyRows({
    required String owner,
    required String resource,
  }) async {
    final cacheKey = _resourceCacheKey(owner, resource);
    final request = _listCache[cacheKey] ??= _loadList(owner, resource);
    try {
      return await request;
    } catch (_) {
      if (identical(_listCache[cacheKey], request)) {
        _listCache.remove(cacheKey);
      }
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> _loadList(
    String owner,
    String resource, {
    bool Function(Map data)? matches,
  }) async {
    final snapshots = await _records
        .find(
          await _db,
          finder: Finder(
            filter: Filter.and([
              Filter.equals('owner', owner.toLowerCase()),
              Filter.equals('resource', resource),
              if (matches != null)
                Filter.custom((snapshot) {
                  final value = snapshot.value;
                  final data = value is Map ? value['data'] : null;
                  return data is Map && matches(data);
                }),
            ]),
          ),
        )
        .timeout(const Duration(seconds: 10));
    return List<Map<String, dynamic>>.unmodifiable(
      snapshots.map(
        (snapshot) =>
            Map<String, dynamic>.unmodifiable(snapshot.value['data']! as Map),
      ),
    );
  }

  /// Filter before projecting rows, without populating the whole-resource cache.
  Future<List<Map<String, dynamic>>> readOnlyMatchingRows({
    required String owner,
    required String resource,
    required bool Function(Map data) matches,
    Object? cacheScope,
  }) async {
    if (cacheScope == null) return _loadList(owner, resource, matches: matches);
    final key = _resourceCacheKey(owner, resource);
    final previous = _scopedLists[key];
    final request = previous != null && previous.$1 == cacheScope
        ? previous.$2
        : _loadList(owner, resource, matches: matches);
    _scopedLists[key] = (cacheScope, request);
    try {
      return await request;
    } catch (_) {
      if (identical(_scopedLists[key]?.$2, request)) _scopedLists.remove(key);
      rethrow;
    }
  }

  Future<void> delete({
    required String owner,
    required String resource,
    required String id,
  }) async {
    _assertDeleteAllowed(owner);
    final database = await _db;
    await database.transaction((transaction) async {
      final record = _records.record(_recordKey(owner, resource, id));
      final previous = await record.get(transaction);
      final existed = previous != null;
      await record.delete(transaction);
      await _adjustLedgerTotal(
        transaction,
        owner,
        resource,
        previous?['data'] as Map?,
        -1,
      );
      if (existed) await _adjustCount(transaction, owner, resource, -1);
    });
    _invalidateResource(owner, resource);
  }

  Future<void> deleteMany({
    required String owner,
    required Iterable<({String resource, String id})> records,
  }) async {
    _assertDeleteAllowed(owner);
    final recordList = records.toList(growable: false);
    final database = await _db;
    await database.transaction((transaction) async {
      final deletedByResource = <String, int>{};
      for (final record in recordList) {
        final stored = _records.record(
          _recordKey(owner, record.resource, record.id),
        );
        final previous = await stored.get(transaction);
        if (previous != null) {
          await stored.delete(transaction);
          await _adjustLedgerTotal(
            transaction,
            owner,
            record.resource,
            previous['data'] as Map?,
            -1,
          );
          deletedByResource.update(
            record.resource,
            (value) => value + 1,
            ifAbsent: () => 1,
          );
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
    _assertDeleteAllowed(owner);
    final database = await _db;
    await database.transaction((transaction) async {
      await _records.delete(
        transaction,
        finder: Finder(filter: Filter.equals('owner', owner.toLowerCase())),
      );
      await _settings.delete(
        transaction,
        finder: Finder(
          filter: Filter.custom((record) {
            final key = record.key.toString();
            final prefix = '${owner.toLowerCase()}::';
            return key.startsWith('${prefix}record_count::') ||
                key.startsWith('${prefix}ledger_total::');
          }),
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

  Future<int> count({required String owner, required String resource}) async {
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

  /// Returns ledger totals from a persistent local index. Existing installs
  /// build missing keys with one detail scan; subsequent writes update them.
  Future<Map<(String, String?), num>> ledgerTotals({
    required String owner,
    required String resource,
    required Iterable<({String accountId, String? currency})> accounts,
  }) async {
    if (!_isLedgerDetailResource(resource)) {
      throw ArgumentError.value(resource, 'resource');
    }
    final requested = accounts.toSet().toList(growable: false);
    if (requested.isEmpty) return const {};
    final database = await _db;
    final values = <(String, String?), num>{};
    final missing = <(String, String?)>[];
    for (final account in requested) {
      final key = _ledgerTotalKey(owner, resource, {
        'account_id': account.accountId,
        if (resource == 'accounting_detail') 'currency': account.currency ?? '',
      });
      final row = await _settings.record(key!).get(database);
      final value = tryParseNumValue(row?['value']);
      final outputKey = (account.accountId, account.currency);
      if (value == null) {
        missing.add(outputKey);
      } else {
        values[outputKey] = value;
      }
    }
    if (missing.isEmpty) return Map.unmodifiable(values);

    final details = await readOnlyRows(owner: owner, resource: resource);
    for (final key in missing) {
      values[key] = 0;
    }
    final missingSet = missing.toSet();
    for (final detail in details) {
      final key = (
        parseStringValue(detail['account_id']),
        resource == 'accounting_detail'
            ? parseStringValue(detail['currency'])
            : null,
      );
      if (!missingSet.contains(key)) continue;
      values[key] = values[key]! + _ledgerValue(resource, detail['value']);
    }
    await database.transaction((transaction) async {
      for (final key in missing) {
        final settingKey = _ledgerTotalKey(owner, resource, {
          'account_id': key.$1,
          if (resource == 'accounting_detail') 'currency': key.$2 ?? '',
        });
        await _settings.record(settingKey!).put(transaction, {
          'value': values[key],
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        });
      }
    });
    return Map.unmodifiable(values);
  }
}
