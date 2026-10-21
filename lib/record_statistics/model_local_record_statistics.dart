import 'package:life_pilot/record_statistics/model_record_statistics.dart';
import 'package:life_pilot/utils/value_parser.dart';

/// Projection of one immutable local resource snapshot for one account/currency.
/// Total and month/history queries share one account scan and date parsing.
/// Month buckets retain source order without rescanning all historical dates.
class ModelLocalRecordStatistics {
  final num total;
  final List<Map<String, dynamic>> _historyRows;
  final Map<(int, int), List<Map<String, dynamic>>> _monthRows;
  ModelLocalRecordStatistics._(this.total, this._historyRows, this._monthRows);

  factory ModelLocalRecordStatistics(
    List<Map<String, dynamic>> source, {
    required String accountId,
    required RecordStatisticsKind kind,
    String? currency,
  }) {
    final history = <Map<String, dynamic>>[];
    final months = <(int, int), List<Map<String, dynamic>>>{};
    num total = 0;
    for (final row in source) {
      if (row['account_id']?.toString() != accountId) continue;
      if (kind == RecordStatisticsKind.accounting &&
          currency != null &&
          row['currency'] != currency) {
        continue;
      }
      total += parseNumValue(row['value']);
      final date = tryParseDateTimeValue(row['date'], toLocal: true);
      // Preserve the original policy: invalid dates count in total, but are
      // absent from both chart history and month rows.
      if (date == null) continue;
      history.add(row);
      (months[(date.year, date.month)] ??= []).add(row);
    }
    return ModelLocalRecordStatistics._(
      total,
      List.unmodifiable(history),
      Map.unmodifiable({
        for (final entry in months.entries)
          entry.key: List<Map<String, dynamic>>.unmodifiable(entry.value),
      }),
    );
  }

  List<Map<String, dynamic>> rows({
    required DateTime now,
    bool history = false,
  }) {
    // Return a private list, matching the previous mutable result contract.
    return List.of(
      history ? _historyRows : _monthRows[(now.year, now.month)] ?? const [],
    );
  }
}
