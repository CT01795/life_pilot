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
    num? knownTotal,
  }) => _select(
    source,
    accountId: accountId,
    type: type,
    from: from,
    to: to,
    includeLatestFallback: includeLatestFallback,
    includeReservedRecords: includeReservedRecords,
    valueOf: parseNumValue,
    knownTotal: knownTotal,
  );

  static ModelLocalRecordPage points(
    Iterable<RecordRow> source, {
    required String accountId,
    required String type,
    required DateTime from,
    required DateTime to,
    bool includeLatestFallback = false,
    bool includeReservedRecords = true,
    num? knownTotal,
  }) => _select(
    source,
    accountId: accountId,
    type: type,
    from: from,
    to: to,
    includeLatestFallback: includeLatestFallback,
    includeReservedRecords: includeReservedRecords,
    valueOf: parseIntValue,
    knownTotal: knownTotal,
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
    required num? knownTotal,
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
      if (knownTotal == null) total += valueOf(row['value']);
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
    return ModelLocalRecordPage._(visible, knownTotal ?? total);
  }
}

/// Reusable projection for an immutable account snapshot. Chronological search
/// uses parsed instants; display ordering retains the existing row comparator.
class ModelLocalRecordDateIndex {
  ModelLocalRecordDateIndex(
    Iterable<RecordRow> source, {
    required String accountId,
    required String type,
    required bool points,
  }) {
    final normalizedType = type.toLowerCase();
    for (final row in source) {
      if (parseStringValue(row['account_id']) != accountId ||
          parseStringValue(row['type']).toLowerCase() != normalizedType) {
        continue;
      }
      _total += points
          ? parseIntValue(row['value'])
          : parseNumValue(row['value']);
      final reserved = isReservedRecordRow(row);
      if (reserved) {
        _reserved.add(row);
      } else if (_latest == null ||
          compareRecordRowsNewestFirst(row, _latest!) < 0) {
        _latest = row;
      }
      final date = recordRowDate(row);
      if (date != null) {
        (reserved ? _datedReserved : _regular).add((date, row));
      }
    }
    int compare((DateTime, RecordRow) a, (DateTime, RecordRow) b) =>
        a.$1.compareTo(b.$1);
    _regular.sort(compare);
    _datedReserved.sort(compare);
  }

  final _regular = <(DateTime, RecordRow)>[];
  final _datedReserved = <(DateTime, RecordRow)>[];
  final _reserved = <RecordRow>[];
  RecordRow? _latest;
  num _total = 0;

  static int _lowerBound(List<(DateTime, RecordRow)> rows, DateTime date) {
    var low = 0;
    var high = rows.length;
    while (low < high) {
      final mid = (low + high) ~/ 2;
      if (rows[mid].$1.isBefore(date)) {
        low = mid + 1;
      } else {
        high = mid;
      }
    }
    return low;
  }

  ModelLocalRecordPage page({
    required DateTime from,
    required DateTime to,
    required bool includeLatestFallback,
    required bool includeReservedRecords,
  }) {
    final end = recordDayUpperBound(to);
    final visible = <RecordRow>[];
    void addRange(List<(DateTime, RecordRow)> rows) {
      final last = _lowerBound(rows, end);
      for (var i = _lowerBound(rows, from); i < last; i++) {
        visible.add(rows[i].$2);
      }
    }

    addRange(_regular);
    if (visible.isEmpty && includeLatestFallback && _latest != null) {
      visible.add(_latest!);
    }
    if (includeReservedRecords) {
      visible.addAll(_reserved);
    } else {
      addRange(_datedReserved);
    }
    sortRecordRowsNewestFirst(visible);
    return ModelLocalRecordPage._(visible, _total);
  }
}
