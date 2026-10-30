import 'package:life_pilot/local_storage/local_data_store.dart';
import 'package:life_pilot/record_statistics/model_record_statistics.dart';
import 'package:life_pilot/record_statistics/model_local_record_statistics.dart';
import 'package:life_pilot/record_statistics/model_record_statistics_query.dart';
import 'package:life_pilot/utils/supabase.dart';
import 'package:life_pilot/utils/const.dart';
import 'package:life_pilot/utils/value_parser.dart';
import 'package:life_pilot/utils/paged_row_reader.dart';

class ServiceRecordStatistics {
  // Performance cache only, unrelated to subscription/storage quotas.
  static const _maximumLocalProjections = 8;
  final LocalDataStore localStore;
  List<Map<String, dynamic>>? _localSource;
  Object? _localScope;
  final Map<(String, String?), ModelLocalRecordStatistics> _localProjections = {};
  ServiceRecordStatistics({LocalDataStore? localStore})
    : localStore = localStore ?? LocalDataStore.instance;

  Future<ModelLocalRecordStatistics?> _readLocal({
    required String owner,
    required String accountId,
    required RecordStatisticsKind kind,
    String? currency,
    bool Function()? shouldContinue,
  }) async {
    final table = kind == RecordStatisticsKind.accounting
        ? TableNames.accountingDetail
        : TableNames.pointRecordDetail;
    final source = await localStore.readOnlyRows(owner: owner, resource: table);
    // A scope change/timeout may occur while opening the local database.
    // Check before scanning values/dates or replacing the cached projection.
    if (shouldContinue?.call() == false) return null;
    final zone = DateTime.now();
    final scope = (
      owner.toLowerCase(),
      kind,
      zone.timeZoneName,
      zone.timeZoneOffset,
    );
    // LocalDataStore replaces its immutable list after writes/deletes/moves.
    // Never retain an aggregate across a changed resource snapshot or scope.
    if (!identical(source, _localSource) || scope != _localScope) {
      _localProjections.clear();
      _localSource = source;
      _localScope = scope;
    }
    final key = (accountId, currency);
    // Refresh insertion order on hits. Alternating between recently viewed
    // accounts no longer discards an unchanged immutable-snapshot projection.
    final cached = _localProjections.remove(key);
    if (cached != null) {
      _localProjections[key] = cached;
      return cached;
    }
    final projection = ModelLocalRecordStatistics(
      source,
      accountId: accountId,
      kind: kind,
      currency: currency,
    );
    if (_localProjections.length >= _maximumLocalProjections) {
      _localProjections.remove(_localProjections.keys.first);
    }
    _localProjections[key] = projection;
    return projection;
  }

  Future<num> readTotal({
    required String owner,
    required DataStorageLocation storage,
    required String accountId,
    required RecordStatisticsKind kind,
    String? currency,
  }) async {
    final points = kind == RecordStatisticsKind.points;
    if (storage == DataStorageLocation.local) {
      final projection = await _readLocal(
        owner: owner,
        accountId: accountId,
        kind: kind,
        currency: currency,
      );
      return projection!.total;
    }
    if (supabase.auth.currentUser?.email?.toLowerCase() !=
        owner.toLowerCase()) {
      throw StateError('Account scope changed');
    }
    final field = points ? 'points' : 'balance';
    final row = await supabase
        .from(
          points ? TableNames.pointRecordAccount : TableNames.accountingAccount,
        )
        .select(field)
        .eq('id', accountId)
        .eq('created_by', owner)
        .eq('is_valid', true)
        .maybeSingle();
    if (row == null) throw StateError('Account not accessible');
    return parseNumValue(row[field]);
  }

  Future<List<Map<String, dynamic>>> read({
    required String owner,
    required DataStorageLocation storage,
    required String accountId,
    required RecordStatisticsKind kind,
    required DateTime now,
    String? currency,
    bool history = false,
    bool Function()? shouldContinue,
  }) async {
    if (shouldContinue?.call() == false) return [];
    if (storage == DataStorageLocation.local) {
      final projection = await _readLocal(
        owner: owner,
        accountId: accountId,
        kind: kind,
        currency: currency,
        shouldContinue: shouldContinue,
      );
      if (projection == null || shouldContinue?.call() == false) return [];
      return projection.rows(now: now, history: history);
    }
    final projection = ModelRecordStatisticsQuery(
      kind: kind,
      now: now,
      currency: currency,
      history: history,
    );
    final normalizedOwner = owner.toLowerCase();
    return readAllPagedRows(
      shouldContinue: shouldContinue,
      fetch: (offset, limit) async {
        if (supabase.auth.currentUser?.email?.toLowerCase() !=
            normalizedOwner) {
          throw StateError('Account scope changed');
        }
        var query = supabase
            .from(projection.tableName)
            .select(projection.columns)
            .eq('account_id', accountId);
        if (projection.currency != null) {
          query = query.eq('currency', projection.currency!);
        }
        if (projection.startUtc != null) {
          query = query
              .gte('date', projection.startUtc!)
              .lt('date', projection.endUtc!);
        }
        return query
            .order('date')
            .order('id')
            .range(offset, offset + limit - 1);
      },
    );
  }
}
