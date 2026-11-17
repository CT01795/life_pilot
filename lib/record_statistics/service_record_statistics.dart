import 'package:life_pilot/accounting/service_ledger_sharing.dart';
import 'package:life_pilot/local_storage/local_data_store.dart';
import 'package:life_pilot/record_statistics/model_record_statistics.dart';
import 'package:life_pilot/record_statistics/model_local_record_statistics.dart';
import 'package:life_pilot/utils/supabase.dart';
import 'package:life_pilot/utils/const.dart';
import 'package:life_pilot/record_statistics/model_record_statistics_buckets.dart';

class ServiceRecordStatistics {
  // Performance cache only, unrelated to subscription/storage quotas.
  static const _maximumLocalProjections = 8;
  final LocalDataStore localStore;
  final String? sharedLedgerId;
  final Map<
    (String, RecordStatisticsKind, String, String?),
    (Object, ModelLocalRecordStatistics)
  >
  _localProjections = {};
  ServiceRecordStatistics({LocalDataStore? localStore, this.sharedLedgerId})
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
    final indexed = await localStore.ledgerStatistics(
      owner: owner,
      resource: table,
      accountId: accountId,
      currency: currency,
      now: DateTime.now(),
      history: true,
      shouldContinue: shouldContinue,
    );
    // A scope change/timeout may occur while opening the local database.
    // Check before scanning values/dates or replacing the cached projection.
    if (shouldContinue?.call() == false) return null;
    final key = (owner.toLowerCase(), kind, accountId, currency);
    // Refresh insertion order on hits. Alternating between recently viewed
    // accounts no longer discards an unchanged immutable-snapshot projection.
    final cached = _localProjections.remove(key);
    if (cached != null && cached.$1 == indexed.revision) {
      _localProjections[key] = cached;
      return cached.$2;
    }
    final projection = ModelLocalRecordStatistics(
      indexed.rows,
      accountId: accountId,
      kind: kind,
      currency: currency,
      totalOverride: indexed.total,
    );
    if (_localProjections.length >= _maximumLocalProjections) {
      _localProjections.remove(_localProjections.keys.first);
    }
    _localProjections[key] = (indexed.revision, projection);
    return projection;
  }

  Future<num> readTotal({
    required String owner,
    required DataStorageLocation storage,
    required String accountId,
    required RecordStatisticsKind kind,
    String? currency,
  }) async {
    if (storage != DataStorageLocation.local) {
      throw StateError('Cloud totals are included in the statistics summary');
    }
    final projection = await _readLocal(
      owner: owner,
      accountId: accountId,
      kind: kind,
      currency: currency,
    );
    return projection!.total;
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
    if (sharedLedgerId case final String id) {
      return ServiceLedgerSharing().statistics(id, now);
    }
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
    final normalizedOwner = owner.toLowerCase();
    final client = supabase;
    if (client.auth.currentUser?.email?.toLowerCase() != normalizedOwner) {
      throw StateError('Account scope changed');
    }
    final summary = await client.rpc(
      'get_my_record_statistics',
      params: {
        'p_account_id': accountId,
        'p_points': kind == RecordStatisticsKind.points,
        'p_currency': currency,
        'p_boundaries': List.generate(
          13,
          (i) =>
              DateTime(now.year, now.month - 11 + i).toUtc().toIso8601String(),
        ),
        'p_day_start': DateTime(
          now.year,
          now.month,
          now.day,
        ).toUtc().toIso8601String(),
        'p_day_end': DateTime(
          now.year,
          now.month,
          now.day + 1,
        ).toUtc().toIso8601String(),
      },
    );
    if (shouldContinue?.call() == false) return [];
    if (client.auth.currentUser?.email?.toLowerCase() != normalizedOwner) {
      throw StateError('Account scope changed');
    }
    if (summary is! Map) {
      throw const FormatException('Invalid statistics summary');
    }
    return ModelRecordStatisticsBuckets.toRows(
      Map<String, dynamic>.from(summary),
      now,
    );
  }
}
