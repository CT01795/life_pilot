import 'package:life_pilot/utils/record_row_utils.dart';
import 'package:life_pilot/utils/value_parser.dart';

/// One-pass local detail projection. Totals include all matching account/type
/// rows; date/reserved/fallback rules only affect the displayed rows.
class ModelLocalRecordPage {
  final List<RecordRow> rows;
  final num total;
  ModelLocalRecordPage._(List<RecordRow> rows, this.total)
    : rows = List.unmodifiable(rows);

  static ModelLocalRecordPage accounting(
    Iterable<RecordRow> source, {
    required String accountId,
    required String type,
    required DateTime from,
    required DateTime to,
    bool includeLatestFallback = false,
    bool includeReservedRecords = true,
  }) => _select(
    source,
    accountId: accountId,
    type: type,
    from: from,
    to: to,
    includeLatestFallback: includeLatestFallback,
    includeReservedRecords: includeReservedRecords,
    valueOf: parseNumValue,
  );

  static ModelLocalRecordPage points(
    Iterable<RecordRow> source, {
    required String accountId,
    required String type,
    required DateTime from,
    required DateTime to,
    bool includeLatestFallback = false,
    bool includeReservedRecords = true,
  }) => _select(
    source,
    accountId: accountId,
    type: type,
    from: from,
    to: to,
    includeLatestFallback: includeLatestFallback,
    includeReservedRecords: includeReservedRecords,
    valueOf: parseIntValue,
  );

  static ModelLocalRecordPage _select(
    Iterable<RecordRow> source, {
    required String accountId,
    required String type,
    required DateTime from,
    required DateTime to,
    required bool includeLatestFallback,
    required bool includeReservedRecords,
    required num Function(Object?) valueOf,
  }) {
    final normalizedType = type.toLowerCase();
    final upperBound = recordDayUpperBound(to);
    final visible = <RecordRow>[];
    RecordRow? latestRegular;
    var hasRegular = false;
    num total = 0;
    for (final row in source) {
      // Preserve detail-page matching: case-insensitive, without trimming type.
      if (parseStringValue(row['account_id']) != accountId ||
          parseStringValue(row['type']).toLowerCase() != normalizedType) {
        continue;
      }
      total += valueOf(row['value']);
      final reserved = isReservedRecordRow(row);
      if (includeLatestFallback &&
          !reserved &&
          (latestRegular == null ||
              compareRecordRowsNewestFirst(row, latestRegular) < 0)) {
        latestRegular = row;
      }
      if (!recordRowIsInRange(
        row,
        from: from,
        upperBound: upperBound,
        includeReservedRecords: includeReservedRecords,
      )) {
        continue;
      }
      visible.add(row);
      if (!reserved) hasRegular = true;
    }
    if (includeLatestFallback && !hasRegular && latestRegular != null) {
      visible.add(latestRegular);
    }
    sortRecordRowsNewestFirst(visible);
    return ModelLocalRecordPage._(visible, total);
  }
}
