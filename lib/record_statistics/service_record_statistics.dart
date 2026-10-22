import 'package:life_pilot/local_storage/local_data_store.dart';
import 'package:life_pilot/record_statistics/model_record_statistics.dart';
import 'package:life_pilot/record_statistics/model_local_record_statistics.dart';
import 'package:life_pilot/utils/api.dart';
import 'package:life_pilot/utils/const.dart';
import 'package:life_pilot/utils/value_parser.dart';
import 'package:life_pilot/utils/paged_row_reader.dart';

class ServiceRecordStatistics {
  final LocalDataStore localStore;
  List<Map<String, dynamic>>? _localSource;
  Object? _localScope;
  ModelLocalRecordStatistics? _localProjection;
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
      accountId,
      kind,
      currency,
      zone.timeZoneName,
      zone.timeZoneOffset,
    );
    // LocalDataStore replaces its immutable list after writes/deletes/moves.
    // Never retain an aggregate across a changed resource snapshot or scope.
    if (!identical(source, _localSource) || scope != _localScope) {
      _localProjection = ModelLocalRecordStatistics(
        source,
        accountId: accountId,
        kind: kind,
        currency: currency,
      );
      _localSource = source;
      _localScope = scope;
    }
    return _localProjection!;
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
    final table = kind == RecordStatisticsKind.accounting
        ? TableNames.accountingDetail
        : TableNames.pointRecordDetail;
    final start = DateTime(now.year, now.month);
    final end = DateTime(now.year, now.month + 1);
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
    return readAllPagedRows(
      shouldContinue: shouldContinue,
      fetch: (offset, limit) async {
        if (supabase.auth.currentUser?.email?.toLowerCase() !=
            owner.toLowerCase()) {
          throw StateError('Account scope changed');
        }
        var query = supabase
            .from(table)
            .select(
              kind == RecordStatisticsKind.accounting
                  ? 'id,date,value,currency'
                  : 'id,date,value',
            )
            .eq('account_id', accountId);
        if (kind == RecordStatisticsKind.accounting && currency != null) {
          query = query.eq('currency', currency);
        }
        if (!history) {
          query = query
              .gte('date', start.toUtc().toIso8601String())
              .lt('date', end.toUtc().toIso8601String());
        }
        return query
            .order('date')
            .order('id')
            .range(offset, offset + limit - 1);
      },
    );
  }
}
