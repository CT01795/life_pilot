import 'package:life_pilot/local_storage/local_data_store.dart';
import 'package:life_pilot/record_statistics/model_record_statistics.dart';
import 'package:life_pilot/utils/api.dart';
import 'package:life_pilot/utils/const.dart';
import 'package:life_pilot/utils/value_parser.dart';

class ServiceRecordStatistics {
  final LocalDataStore localStore;
  ServiceRecordStatistics({LocalDataStore? localStore})
    : localStore = localStore ?? LocalDataStore.instance;
  Future<num> readTotal({
    required String owner,
    required DataStorageLocation storage,
    required String accountId,
    required RecordStatisticsKind kind,
    String? currency,
  }) async {
    final points = kind == RecordStatisticsKind.points;
    if (storage == DataStorageLocation.local) {
      final rows = await localStore.readOnlyRows(
        owner: owner,
        resource: points
            ? TableNames.pointRecordDetail
            : TableNames.accountingDetail,
      );
      return rows
          .where(
            (row) =>
                row['account_id']?.toString() == accountId &&
                (points || currency == null || row['currency'] == currency),
          )
          .fold<num>(0, (sum, row) => sum + parseNumValue(row['value']));
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
  }) async {
    final table = kind == RecordStatisticsKind.accounting
        ? TableNames.accountingDetail
        : TableNames.pointRecordDetail;
    final start = DateTime(now.year, now.month);
    final end = DateTime(now.year, now.month + 1);
    if (storage == DataStorageLocation.local) {
      final rows = await localStore.readOnlyRows(owner: owner, resource: table);
      return rows.where((row) {
        if (row['account_id']?.toString() != accountId) return false;
        if (kind == RecordStatisticsKind.accounting &&
            currency != null &&
            row['currency'] != currency) {
          return false;
        }
        final date = tryParseDateTimeValue(row['date'], toLocal: true);
        return date != null &&
            (history || (!date.isBefore(start) && date.isBefore(end)));
      }).toList();
    }
    final result = <Map<String, dynamic>>[];
    final seen = <String>{};
    // Empty pages, not short responses, mark the end under a server row cap.
    while (true) {
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
      final rows = await query
          .order('date')
          .order('id')
          .range(result.length, result.length + 499);
      if (rows.isEmpty) break;
      for (final row in rows) {
        if (!seen.add(row['id'].toString())) {
          throw StateError('Repeated statistics page');
        }
        result.add(Map<String, dynamic>.from(row));
      }
    }
    return result;
  }
}
