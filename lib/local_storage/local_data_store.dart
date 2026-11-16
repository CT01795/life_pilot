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

  String _detailScopeKey(String owner, String resource, Map? data) {
    final accountId = parseStringValue(data?['account_id']);
    final type = parseStringValue(data?['type']).toLowerCase();
    return '${owner.toLowerCase()}::ledger_scope::$resource::$accountId::$type';
  }

  String _defaultAccountKey(String owner, String resource) =>
      '${owner.toLowerCase()}::default_account::$resource';

  String _calendarWindowKey(String owner, String resource) =>
      '${owner.toLowerCase()}::calendar_window::$resource';

  String _eventDateIndexKey(String owner, String resource) =>
      '${owner.toLowerCase()}::event_date_index::$resource';

  bool _isLedgerDetailResource(String resource) =>
      resource == 'accounting_detail' || resource == 'point_record_detail';

  bool _isLedgerAccountResource(String resource) =>
      resource == 'accounting_account' || resource == 'point_record_account';

  bool _isIndexedEventResource(String resource) =>
      resource == 'calendar_events' || resource == 'memory_trace';

  Future<void> _adjustEventDateIndex(
    DatabaseClient database,
    String owner,
    String resource,
    String id,
    Map? data,
    bool add,
  ) async {
    if (!_isIndexedEventResource(resource) || data == null) return;
    final record = _settings.record(_eventDateIndexKey(owner, resource));
    final cached = await record.get(database);
    if (cached?['version'] != 2 ||
        cached?['entries'] is! List ||
        cached?['undated_ids'] is! List) {
      return;
    }
    final entries = (cached!['entries'] as List)
        .map((entry) => Map<String, dynamic>.from(entry as Map))
        .where((entry) => parseStringValue(entry['id']) != id)
        .toList();
    final undatedIds = (cached['undated_ids'] as List)
        .map(parseStringValue)
        .where((value) => value.isNotEmpty && value != id)
        .toList();
    if (add) {
      final date = tryParseDateTimeValue(data['start_date']);
      if (date != null) {
        entries.add({'id': id, 'date': date.toUtc().toIso8601String()});
      } else {
        undatedIds.add(id);
      }
    }
    entries.sort((left, right) {
      final byDate = parseStringValue(
        left['date'],
      ).compareTo(parseStringValue(right['date']));
      return byDate != 0
          ? byDate
          : parseStringValue(
              left['id'],
            ).compareTo(parseStringValue(right['id']));
    });
    await record.put(database, {
      'version': 2,
      'entries': entries,
      'undated_ids': undatedIds,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  Future<Map<String, Object?>> _eventDateIndex(
    Database database,
    String owner,
    String resource,
  ) async {
    final key = _eventDateIndexKey(owner, resource);
    final cached = await _settings.record(key).get(database);
    if (cached?['version'] == 2 &&
        cached?['entries'] is List &&
        cached?['undated_ids'] is List) {
      return Map<String, Object?>.from(cached!);
    }
    return database.transaction((transaction) async {
      final existing = await _settings.record(key).get(transaction);
      if (existing?['version'] == 2 &&
          existing?['entries'] is List &&
          existing?['undated_ids'] is List) {
        return Map<String, Object?>.from(existing!);
      }
      final snapshots = await _records.find(
        transaction,
        finder: Finder(
          filter: Filter.and([
            Filter.equals('owner', owner.toLowerCase()),
            Filter.equals('resource', resource),
          ]),
        ),
      );
      final entries = <Map<String, dynamic>>[];
      final undatedIds = <String>[];
      for (final snapshot in snapshots) {
        final data = snapshot.value['data'];
        if (data is! Map) continue;
        final id = parseStringValue(snapshot.value['id']);
        final date = tryParseDateTimeValue(data['start_date']);
        if (date == null) {
          undatedIds.add(id);
        } else {
          entries.add({'id': id, 'date': date.toUtc().toIso8601String()});
        }
      }
      entries.sort((left, right) {
        final byDate = parseStringValue(
          left['date'],
        ).compareTo(parseStringValue(right['date']));
        return byDate != 0
            ? byDate
            : parseStringValue(
                left['id'],
              ).compareTo(parseStringValue(right['id']));
      });
      final built = <String, Object?>{
        'version': 2,
        'entries': entries,
        'undated_ids': undatedIds,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };
      await _settings.record(key).put(transaction, built);
      return built;
    });
  }

  Future<void> _adjustDetailScope(
    DatabaseClient database,
    String owner,
    String resource,
    String id,
    Map? data,
    bool add,
  ) async {
    if (!_isLedgerDetailResource(resource) || data == null) return;
    final key = _detailScopeKey(owner, resource, data);
    final record = _settings.record(key);
    final cached = await record.get(database);
    if (cached?['ids'] is! List) return;
    final ids = (cached!['ids'] as List)
        .map(parseStringValue)
        .where((value) => value.isNotEmpty && value != id)
        .toList();
    if (add) ids.add(id);
    await record.put(database, {
      'ids': ids,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  bool _calendarMatches(Map data, DateTime start, DateTime end) {
    if (data['is_completed'] == true) return false;
    final eventStart = tryParseDateTimeValue(data['start_date'], toLocal: true);
    if (eventStart == null || !eventStart.isBefore(end)) return false;
    final eventEnd = tryParseDateTimeValue(data['end_date'], toLocal: true);
    return !(eventEnd ?? eventStart).isBefore(start);
  }

  Future<void> _adjustCalendarWindow(
    DatabaseClient database,
    String owner,
    String resource,
    String id,
    Map? data,
    bool add,
  ) async {
    if (resource != 'calendar_events' || data == null) return;
    final record = _settings.record(_calendarWindowKey(owner, resource));
    final cached = await record.get(database);
    if (cached?['ids'] is! List) return;
    final start = tryParseDateTimeValue(cached?['start'], toLocal: true);
    final end = tryParseDateTimeValue(cached?['end'], toLocal: true);
    if (start == null || end == null) return;
    final ids = (cached!['ids'] as List)
        .map(parseStringValue)
        .where((value) => value.isNotEmpty && value != id)
        .toList();
    if (add && _calendarMatches(data, start, end)) ids.add(id);
    await record.put(database, {
      ...cached,
      'ids': ids,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  Future<void> _seedDefaultAccount(
    DatabaseClient database,
    String owner,
    String resource,
    String id,
    Map? data,
  ) async {
    if (!_isLedgerAccountResource(resource) || data?['is_valid'] != true) {
      return;
    }
    final record = _settings.record(_defaultAccountKey(owner, resource));
    if (await record.get(database) == null) {
      await record.put(database, {
        'id': id,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });
    }
  }

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

  String? _ledgerStatisticsKey(String owner, String resource, Map? data) {
    if (!_isLedgerDetailResource(resource) || data == null) return null;
    final accountId = parseStringValue(data['account_id']);
    if (accountId.isEmpty) return null;
    final currency = resource == 'accounting_detail'
        ? data['_all_currencies'] == true
              ? '*'
              : parseStringValue(data['currency'])
        : '';
    return '${owner.toLowerCase()}::ledger_statistics::$resource::$accountId::$currency';
  }

  String _dayToken(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  String? _ledgerDayKey(String owner, String resource, Map? data) {
    if (!_isLedgerDetailResource(resource) || data == null) return null;
    final accountId = parseStringValue(data['account_id']);
    final date = tryParseDateTimeValue(data['date'], toLocal: true);
    if (accountId.isEmpty || date == null) return null;
    final currency = resource == 'accounting_detail'
        ? parseStringValue(data['currency'])
        : '';
    return '${owner.toLowerCase()}::ledger_day::$resource::$accountId::$currency::${_dayToken(date)}';
  }

  Future<void> _adjustLedgerDay(
    DatabaseClient database,
    String owner,
    String resource,
    String id,
    Map? data,
    num direction,
  ) async {
    final key = _ledgerDayKey(owner, resource, data);
    if (key == null) return;
    final record = _settings.record(key);
    final cached = await record.get(database);
    final current = tryParseNumValue(cached?['value']);
    if (current == null || cached?['entries'] is! List) return;
    final entries = (cached!['entries'] as List)
        .map((entry) => Map<String, dynamic>.from(entry as Map))
        .where((entry) => entry['id'] != id)
        .toList();
    if (direction > 0) {
      entries.add({'id': id, 'date': parseStringValue(data?['date'])});
      entries.sort((left, right) {
        final byDate = parseStringValue(
          right['date'],
        ).compareTo(parseStringValue(left['date']));
        return byDate != 0
            ? byDate
            : parseStringValue(
                left['id'],
              ).compareTo(parseStringValue(right['id']));
      });
    }
    await record.put(database, {
      'value': current + _ledgerValue(resource, data?['value']) * direction,
      'entries': entries,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });
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

  Future<void> _adjustLedgerStatistics(
    DatabaseClient database,
    String owner,
    String resource,
    Map? data,
    int direction,
  ) async {
    if (data == null) return;
    final scopes = <Map>{
      data,
      if (resource == 'accounting_detail') {...data, '_all_currencies': true},
    };
    for (final scope in scopes) {
      final key = _ledgerStatisticsKey(owner, resource, scope);
      if (key == null) continue;
      final record = _settings.record(key);
      final cached = await record.get(database);
      if (cached?['version'] != 1 || cached?['days'] is! Map) continue;
      final days = Map<String, dynamic>.from(cached!['days'] as Map);
      final date = tryParseDateTimeValue(data['date'], toLocal: true);
      if (date != null) {
        final token = _dayToken(date);
        final previous = days[token] is Map
            ? Map<String, dynamic>.from(days[token] as Map)
            : <String, dynamic>{};
        final count = parseIntValue(previous['count']) + direction;
        if (count <= 0) {
          days.remove(token);
        } else {
          days[token] = {
            'count': count,
            'value':
                parseNumValue(previous['value']) +
                _ledgerValue(resource, data['value']) * direction,
          };
        }
      }
      await record.put(database, {
        'version': 1,
        'total':
            parseNumValue(cached['total']) +
            _ledgerValue(resource, data['value']) * direction,
        'days': days,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });
    }
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
      await _adjustLedgerStatistics(
        transaction,
        owner,
        resource,
        previous?['data'] as Map?,
        -1,
      );
      await _adjustLedgerDay(
        transaction,
        owner,
        resource,
        id,
        previous?['data'] as Map?,
        -1,
      );
      await _adjustDetailScope(
        transaction,
        owner,
        resource,
        id,
        previous?['data'] as Map?,
        false,
      );
      await _adjustCalendarWindow(
        transaction,
        owner,
        resource,
        id,
        previous?['data'] as Map?,
        false,
      );
      await _adjustEventDateIndex(
        transaction,
        owner,
        resource,
        id,
        previous?['data'] as Map?,
        false,
      );
      await _adjustLedgerTotal(transaction, owner, resource, data, 1);
      await _adjustLedgerStatistics(transaction, owner, resource, data, 1);
      await _adjustLedgerDay(transaction, owner, resource, id, data, 1);
      await _adjustDetailScope(transaction, owner, resource, id, data, true);
      await _adjustCalendarWindow(transaction, owner, resource, id, data, true);
      await _adjustEventDateIndex(transaction, owner, resource, id, data, true);
      await _seedDefaultAccount(transaction, owner, resource, id, data);
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

  /// Returns only the first matching row and never fills the whole-resource
  /// cache. Use this for existence checks and targeted recovery paths.
  Future<Map<String, dynamic>?> readOnlyFirstMatchingRow({
    required String owner,
    required String resource,
    required bool Function(Map data) matches,
  }) async {
    final snapshots = await _records
        .find(
          await _db,
          finder: Finder(
            filter: Filter.and([
              Filter.equals('owner', owner.toLowerCase()),
              Filter.equals('resource', resource),
              Filter.custom((snapshot) {
                final value = snapshot.value;
                final data = value is Map ? value['data'] : null;
                return data is Map && matches(data);
              }),
            ]),
            limit: 1,
          ),
        )
        .timeout(const Duration(seconds: 10));
    if (snapshots.isEmpty) return null;
    return Map<String, dynamic>.unmodifiable(
      snapshots.single.value['data']! as Map,
    );
  }

  /// Returns a bounded owner/resource page after filtering in the database.
  Future<List<Map<String, dynamic>>> readOnlyMatchingPage({
    required String owner,
    required String resource,
    required bool Function(Map data) matches,
    required int offset,
    required int limit,
  }) async {
    if (offset < 0 || limit < 1) throw ArgumentError('Invalid local page');
    final snapshots = await _records
        .find(
          await _db,
          finder: Finder(
            filter: Filter.and([
              Filter.equals('owner', owner.toLowerCase()),
              Filter.equals('resource', resource),
              Filter.custom((snapshot) {
                final value = snapshot.value;
                final data = value is Map ? value['data'] : null;
                return data is Map && matches(data);
              }),
            ]),
            offset: offset,
            limit: limit,
          ),
        )
        .timeout(const Duration(seconds: 10));
    return List.unmodifiable([
      for (final snapshot in snapshots)
        Map<String, dynamic>.unmodifiable(snapshot.value['data']! as Map),
    ]);
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
      await _adjustLedgerStatistics(
        transaction,
        owner,
        resource,
        previous?['data'] as Map?,
        -1,
      );
      await _adjustLedgerDay(
        transaction,
        owner,
        resource,
        id,
        previous?['data'] as Map?,
        -1,
      );
      await _adjustDetailScope(
        transaction,
        owner,
        resource,
        id,
        previous?['data'] as Map?,
        false,
      );
      await _adjustCalendarWindow(
        transaction,
        owner,
        resource,
        id,
        previous?['data'] as Map?,
        false,
      );
      await _adjustEventDateIndex(
        transaction,
        owner,
        resource,
        id,
        previous?['data'] as Map?,
        false,
      );
      if (existed) await _adjustCount(transaction, owner, resource, -1);
    });
    _invalidateResource(owner, resource);
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
                key.startsWith('${prefix}ledger_total::') ||
                key.startsWith('${prefix}ledger_statistics::') ||
                key.startsWith('${prefix}ledger_day::') ||
                key.startsWith('${prefix}ledger_scope::') ||
                key.startsWith('${prefix}default_account::') ||
                key.startsWith('${prefix}calendar_window::') ||
                key.startsWith('${prefix}event_date_index::');
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

  /// Reads only one account/type detail scope. Existing installs build the
  /// persistent ID index once; later writes maintain it transactionally.
  Future<List<Map<String, dynamic>>> ledgerScopeRows({
    required String owner,
    required String resource,
    required String accountId,
    required String type,
  }) async {
    if (!_isLedgerDetailResource(resource)) {
      throw ArgumentError.value(resource, 'resource');
    }
    final probe = {'account_id': accountId, 'type': type};
    final key = _detailScopeKey(owner, resource, probe);
    final database = await _db;
    var cached = await _settings.record(key).get(database);
    if (cached?['ids'] is! List) {
      cached = await database.transaction((transaction) async {
        final existing = await _settings.record(key).get(transaction);
        if (existing?['ids'] is List) return existing;
        final snapshots = await _records.find(
          transaction,
          finder: Finder(
            filter: Filter.and([
              Filter.equals('owner', owner.toLowerCase()),
              Filter.equals('resource', resource),
              Filter.custom((snapshot) {
                final value = snapshot.value;
                if (value is! Map) return false;
                final data = value['data'];
                return data is Map &&
                    parseStringValue(data['account_id']) == accountId &&
                    parseStringValue(data['type']).toLowerCase() ==
                        type.toLowerCase();
              }),
            ]),
          ),
        );
        final built = <String, Object?>{
          'ids': [
            for (final snapshot in snapshots)
              parseStringValue(snapshot.value['id']),
          ],
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        };
        await _settings.record(key).put(transaction, built);
        return built;
      });
    }
    final index = cached;
    if (index == null || index['ids'] is! List) {
      throw StateError('Local ledger scope index was not created');
    }
    final rows = <Map<String, dynamic>>[];
    for (final id in index['ids'] as List) {
      final snapshot = await _records
          .record(_recordKey(owner, resource, parseStringValue(id)))
          .get(database);
      final data = snapshot?['data'];
      if (data is Map) rows.add(Map<String, dynamic>.unmodifiable(data));
    }
    return List.unmodifiable(rows);
  }

  /// Returns the current local calendar window without loading all events.
  Future<List<Map<String, dynamic>>> calendarRowsInRange({
    required String owner,
    required String resource,
    required DateTime start,
    required DateTime end,
  }) async {
    if (resource != 'calendar_events' || !end.isAfter(start)) {
      throw ArgumentError('Invalid calendar range');
    }
    final key = _calendarWindowKey(owner, resource);
    final database = await _db;
    var cached = await _settings.record(key).get(database);
    final cachedStart = tryParseDateTimeValue(cached?['start'], toLocal: true);
    final cachedEnd = tryParseDateTimeValue(cached?['end'], toLocal: true);
    if (cached?['ids'] is! List || cachedStart != start || cachedEnd != end) {
      final snapshots = await _records.find(
        database,
        finder: Finder(
          filter: Filter.and([
            Filter.equals('owner', owner.toLowerCase()),
            Filter.equals('resource', resource),
            Filter.custom((snapshot) {
              final value = snapshot.value;
              if (value is! Map) return false;
              final data = value['data'];
              return data is Map && _calendarMatches(data, start, end);
            }),
          ]),
        ),
      );
      cached = <String, Object?>{
        'start': start.toIso8601String(),
        'end': end.toIso8601String(),
        'ids': [
          for (final snapshot in snapshots)
            parseStringValue(snapshot.value['id']),
        ],
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };
      await _settings.record(key).put(database, cached);
    }
    final index = cached;
    if (index == null || index['ids'] is! List) {
      throw StateError('Local calendar window index was not created');
    }
    final rows = <Map<String, dynamic>>[];
    for (final id in index['ids'] as List) {
      final snapshot = await _records
          .record(_recordKey(owner, resource, parseStringValue(id)))
          .get(database);
      final data = snapshot?['data'];
      if (data is Map) rows.add(Map<String, dynamic>.unmodifiable(data));
    }
    return List.unmodifiable(rows);
  }

  /// Returns the first valid local account using a persistent pointer.
  Future<Map<String, dynamic>?> defaultAccount({
    required String owner,
    required String resource,
  }) async {
    if (!_isLedgerAccountResource(resource)) {
      throw ArgumentError.value(resource, 'resource');
    }
    final database = await _db;
    final setting = _settings.record(_defaultAccountKey(owner, resource));
    final cached = await setting.get(database);
    final id = parseStringValue(cached?['id']);
    if (id.isNotEmpty) {
      final row = await readOnlyRow(owner: owner, resource: resource, id: id);
      if (row?['is_valid'] == true) return row;
    }
    final snapshots = await _records.find(
      database,
      finder: Finder(
        filter: Filter.and([
          Filter.equals('owner', owner.toLowerCase()),
          Filter.equals('resource', resource),
          Filter.custom((snapshot) {
            final value = snapshot.value;
            if (value is! Map) return false;
            final data = value['data'];
            return data is Map && data['is_valid'] == true;
          }),
        ]),
        limit: 1,
      ),
    );
    if (snapshots.isEmpty) {
      await setting.delete(database);
      return null;
    }
    final snapshot = snapshots.first;
    await setting.put(database, {
      'id': parseStringValue(snapshot.value['id']),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });
    final data = snapshot.value['data'];
    if (data is! Map) return null;
    return Map<String, dynamic>.unmodifiable(data);
  }

  /// Finds the newest local event before [before] from a persistent date
  /// index. Existing installs build the index once; writes keep it current.
  Future<Map<String, dynamic>?> eventRowBefore({
    required String owner,
    required String resource,
    required DateTime before,
  }) async {
    if (!_isIndexedEventResource(resource)) {
      throw ArgumentError.value(resource, 'resource');
    }
    final database = await _db;
    final entries = (await _eventDateIndex(
      database,
      owner,
      resource,
    ))['entries'];
    if (entries is! List) {
      throw StateError('Local event date index was not created');
    }
    final boundary = before.toUtc();
    for (final value in entries.reversed) {
      final entry = value as Map;
      final date = tryParseDateTimeValue(entry['date']);
      if (date == null || !date.isBefore(boundary)) continue;
      return readOnlyRow(
        owner: owner,
        resource: resource,
        id: parseStringValue(entry['id']),
      );
    }
    return null;
  }

  /// Reads only events whose local calendar date is inside the inclusive
  /// window. Missing and malformed dates remain visible as in the legacy
  /// local query, without forcing every dated row to be loaded.
  Future<List<Map<String, dynamic>>> eventRowsInRange({
    required String owner,
    required String resource,
    required DateTime start,
    required DateTime end,
  }) async {
    if (!_isIndexedEventResource(resource) || end.isBefore(start)) {
      throw ArgumentError('Invalid event range');
    }
    final database = await _db;
    final index = await _eventDateIndex(database, owner, resource);
    final from = DateTime(start.year, start.month, start.day);
    final through = DateTime(end.year, end.month, end.day);
    final ids = <String>[
      for (final value in index['entries']! as List)
        if (tryParseDateTimeValue((value as Map)['date'], toLocal: true)
            case final DateTime date
            when !DateTime(date.year, date.month, date.day).isBefore(from) &&
                !DateTime(date.year, date.month, date.day).isAfter(through))
          parseStringValue(value['id']),
      for (final id in index['undated_ids']! as List) parseStringValue(id),
    ];
    final rows = <Map<String, dynamic>>[];
    for (final id in ids) {
      final row = await readOnlyRow(owner: owner, resource: resource, id: id);
      if (row != null) rows.add(row);
    }
    return List.unmodifiable(rows);
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

    final missingSet = missing.toSet();
    final details = await readOnlyMatchingRows(
      owner: owner,
      resource: resource,
      matches: (detail) {
        final key = (
          parseStringValue(detail['account_id']),
          resource == 'accounting_detail'
              ? parseStringValue(detail['currency'])
              : null,
        );
        return missingSet.contains(key);
      },
    );
    for (final key in missing) {
      values[key] = 0;
    }
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

  /// Returns daily aggregates for one ledger account. Existing data is
  /// filtered to the requested account once; later writes maintain the index.
  Future<({num total, List<Map<String, dynamic>> rows, Object revision})>
  ledgerStatistics({
    required String owner,
    required String resource,
    required String accountId,
    String? currency,
    required DateTime now,
    required bool history,
    bool Function()? shouldContinue,
  }) async {
    if (!_isLedgerDetailResource(resource) || accountId.isEmpty) {
      throw ArgumentError('Invalid ledger statistics scope');
    }
    final scope = <String, Object?>{
      'account_id': accountId,
      if (resource == 'accounting_detail' && currency != null)
        'currency': currency,
      if (resource == 'accounting_detail' && currency == null)
        '_all_currencies': true,
    };
    final key = _ledgerStatisticsKey(owner, resource, scope)!;
    final database = await _db;
    var cached = await _settings.record(key).get(database);
    if (cached?['version'] != 1 || cached?['days'] is! Map) {
      final details = await readOnlyMatchingRows(
        owner: owner,
        resource: resource,
        matches: (row) =>
            parseStringValue(row['account_id']) == accountId &&
            (resource != 'accounting_detail' ||
                currency == null ||
                parseStringValue(row['currency']) == currency),
      );
      num total = 0;
      final days = <String, Map<String, Object?>>{};
      for (final detail in details) {
        if (shouldContinue?.call() == false) {
          return (
            total: 0 as num,
            rows: const <Map<String, dynamic>>[],
            revision: Object(),
          );
        }
        final value = _ledgerValue(resource, detail['value']);
        total += value;
        final date = tryParseDateTimeValue(detail['date'], toLocal: true);
        if (date == null) continue;
        final token = _dayToken(date);
        final day = days[token] ?? const {'count': 0, 'value': 0};
        days[token] = {
          'count': parseIntValue(day['count']) + 1,
          'value': parseNumValue(day['value']) + value,
        };
      }
      cached = <String, Object?>{
        'version': 1,
        'total': total,
        'days': days,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };
      await _settings.record(key).put(database, cached);
    }
    final days = Map<String, dynamic>.from(cached!['days'] as Map);
    final monthPrefix =
        '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-';
    final tokens =
        days.keys
            .where((token) => history || token.startsWith(monthPrefix))
            .toList()
          ..sort();
    return (
      total: parseNumValue(cached['total']),
      rows: List<Map<String, dynamic>>.unmodifiable([
        for (final token in tokens)
          {
            'account_id': accountId,
            'date': '${token}T12:00:00',
            'value': parseNumValue((days[token] as Map)['value']),
            if (resource == 'accounting_detail' && currency != null)
              'currency': currency,
          },
      ]),
      revision: cached['updated_at'] ?? cached,
    );
  }

  /// Returns one local ledger day's total and newest rows from a persistent
  /// index. Existing installs scan the detail resource once for a missing day;
  /// later writes maintain the index in the same transaction as the record.
  Future<({num total, List<Map<String, dynamic>> rows})> ledgerDaySummary({
    required String owner,
    required String resource,
    required String accountId,
    required DateTime day,
    String? currency,
    int previewLimit = 5,
  }) async {
    if (!_isLedgerDetailResource(resource)) {
      throw ArgumentError.value(resource, 'resource');
    }
    if (previewLimit < 0) {
      throw ArgumentError.value(previewLimit, 'previewLimit');
    }
    final probe = <String, Object?>{
      'account_id': accountId,
      'date': day.toIso8601String(),
      if (resource == 'accounting_detail') 'currency': currency ?? '',
    };
    final key = _ledgerDayKey(owner, resource, probe)!;
    final database = await _db;
    var cached = await _settings.record(key).get(database);
    if (tryParseNumValue(cached?['value']) == null ||
        cached?['entries'] is! List) {
      cached = await database.transaction((transaction) async {
        final existing = await _settings.record(key).get(transaction);
        if (tryParseNumValue(existing?['value']) != null &&
            existing?['entries'] is List) {
          return existing;
        }
        final token = _dayToken(day);
        num total = 0;
        final entries = <Map<String, dynamic>>[];
        final snapshots = await _records.find(
          transaction,
          finder: Finder(
            filter: Filter.and([
              Filter.equals('owner', owner.toLowerCase()),
              Filter.equals('resource', resource),
            ]),
          ),
        );
        for (final snapshot in snapshots) {
          final data = snapshot.value['data'];
          if (data is! Map ||
              parseStringValue(data['account_id']) != accountId ||
              (resource == 'accounting_detail' &&
                  parseStringValue(data['currency']) != (currency ?? ''))) {
            continue;
          }
          final date = tryParseDateTimeValue(data['date'], toLocal: true);
          if (date == null || _dayToken(date) != token) continue;
          total += _ledgerValue(resource, data['value']);
          entries.add({
            'id': parseStringValue(snapshot.value['id']),
            'date': parseStringValue(data['date']),
          });
        }
        entries.sort((left, right) {
          final byDate = parseStringValue(
            right['date'],
          ).compareTo(parseStringValue(left['date']));
          return byDate != 0
              ? byDate
              : parseStringValue(
                  left['id'],
                ).compareTo(parseStringValue(right['id']));
        });
        final built = <String, Object?>{
          'value': total,
          'entries': entries,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        };
        await _settings.record(key).put(transaction, built);
        return built;
      });
    }
    final total = tryParseNumValue(cached?['value']) ?? 0;
    final ids = (cached?['entries'] as List? ?? const [])
        .take(previewLimit)
        .map((entry) => parseStringValue((entry as Map)['id']))
        .where((id) => id.isNotEmpty)
        .toList(growable: false);
    final rows = <Map<String, dynamic>>[];
    for (final id in ids) {
      final snapshot = await _records
          .record(_recordKey(owner, resource, id))
          .get(database);
      final data = snapshot?['data'];
      if (data is Map) {
        rows.add(Map<String, dynamic>.unmodifiable(data));
      }
    }
    return (total: total, rows: List<Map<String, dynamic>>.unmodifiable(rows));
  }
}
