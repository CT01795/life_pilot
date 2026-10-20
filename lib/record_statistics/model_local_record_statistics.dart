import 'package:life_pilot/record_statistics/model_record_statistics.dart';
import 'package:life_pilot/utils/value_parser.dart';

/// Projection of one immutable local resource snapshot for one account/currency.
/// Total and month/history queries share the account scan and date parsing.
class ModelLocalRecordStatistics {
  final num total;
  final List<({Map<String, dynamic> row, DateTime? date})> _records;
  ModelLocalRecordStatistics._(this.total, this._records);

  factory ModelLocalRecordStatistics(
    List<Map<String, dynamic>> source, {
    required String accountId,
    required RecordStatisticsKind kind,
    String? currency,
  }) {
    final records = <({Map<String, dynamic> row, DateTime? date})>[];
    num total = 0;
    for (final row in source) {
      if (row['account_id']?.toString() != accountId) continue;
      if (kind == RecordStatisticsKind.accounting &&
          currency != null &&
          row['currency'] != currency) {
        continue;
      }
      total += parseNumValue(row['value']);
      records.add((
        row: row,
        date: tryParseDateTimeValue(row['date'], toLocal: true),
      ));
    }
    return ModelLocalRecordStatistics._(total, List.unmodifiable(records));
  }

  List<Map<String, dynamic>> rows({
    required DateTime now,
    bool history = false,
  }) {
    final start = DateTime(now.year, now.month);
    final end = DateTime(now.year, now.month + 1);
    return [
      for (final record in _records)
        if (record.date != null &&
            (history ||
                (!record.date!.isBefore(start) && record.date!.isBefore(end))))
          record.row,
    ];
  }
}
