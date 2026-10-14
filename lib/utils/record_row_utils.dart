import 'package:life_pilot/utils/const.dart';
import 'package:life_pilot/utils/value_parser.dart';

typedef RecordRow = Map<String, dynamic>;

const String reservedRecordCategory = 'reserved';

DateTime recordDayUpperBound(DateTime date) =>
    DateTime(date.year, date.month, date.day + 1);

/// PostgREST date range including records retained regardless of their date.
String recordRangeOrReservedFilter({
  required DateTime from,
  required DateTime upperBound,
}) =>
    'and(date.gte.${from.toUtc().toIso8601String()},'
    'date.lt.${upperBound.toUtc().toIso8601String()}),'
    'primary_category.eq.$reservedRecordCategory';

int compareRecordRowsNewestFirst(RecordRow a, RecordRow b) =>
    parseStringValue(b['date']).compareTo(parseStringValue(a['date']));

DateTime? recordRowDate(RecordRow row) => tryParseDateTimeValue(row['date']);

bool isReservedRecordRow(RecordRow row) =>
    row['primary_category'] == reservedRecordCategory;

bool recordRowMatchesAccountAndType(
  RecordRow row, {
  required String accountId,
  required String type,
}) =>
    parseStringValue(row['account_id']) == accountId &&
    normalizeStringValue(row['type']) == type.toLowerCase();

RecordRow? latestRecordRowWhere(
  Iterable<RecordRow> rows,
  bool Function(RecordRow row) matches,
) {
  RecordRow? latest;
  for (final row in rows) {
    if (!matches(row)) continue;
    if (latest == null || compareRecordRowsNewestFirst(row, latest) < 0) {
      latest = row;
    }
  }
  return latest;
}

RecordRow? latestRecordRowForAccountAndType(
  Iterable<RecordRow> rows, {
  required String accountId,
  required String type,
}) => latestRecordRowWhere(
  rows,
  (row) =>
      recordRowMatchesAccountAndType(row, accountId: accountId, type: type),
);

RecordRow? latestRecordRowForEvent(Iterable<RecordRow> rows, String eventId) =>
    latestRecordRowWhere(
      rows,
      (row) => parseStringValue(row['event_id']) == eventId,
    );

bool recordRowIsInRange(
  RecordRow row, {
  required DateTime from,
  required DateTime upperBound,
  required bool includeReservedRecords,
}) {
  if (includeReservedRecords && isReservedRecordRow(row)) return true;
  final date = recordRowDate(row);
  return date != null && !date.isBefore(from) && date.isBefore(upperBound);
}

List<RecordRow> filterRecordRows(
  Iterable<RecordRow> rows, {
  required DateTime from,
  required DateTime to,
  bool includeLatestFallback = false,
  bool includeReservedRecords = true,
}) {
  final source = rows.toList();
  final upperBound = recordDayUpperBound(to);
  final filtered = source
      .where(
        (row) => recordRowIsInRange(
          row,
          from: from,
          upperBound: upperBound,
          includeReservedRecords: includeReservedRecords,
        ),
      )
      .toList();

  if (includeLatestFallback &&
      !filtered.any((row) => !isReservedRecordRow(row))) {
    final fallback = latestRecordRowWhere(
      source,
      (row) => !isReservedRecordRow(row),
    );
    if (fallback != null) filtered.add(fallback);
  }

  sortRecordRowsNewestFirst(filtered);
  return filtered;
}

bool hasRecordRowBefore(Iterable<RecordRow> rows, DateTime before) =>
    rows.any((row) {
      final date = recordRowDate(row);
      return !isReservedRecordRow(row) && date != null && date.isBefore(before);
    });

DateTime? latestRecordRowDateBefore(Iterable<RecordRow> rows, DateTime before) {
  DateTime? latest;
  for (final row in rows) {
    if (isReservedRecordRow(row)) continue;
    final date = recordRowDate(row);
    if (date == null || !date.isBefore(before)) continue;
    if (latest == null || date.isAfter(latest)) latest = date;
  }
  return latest?.toLocal();
}

List<RecordRow> uniqueRecordRowsNewestFirst(Iterable<RecordRow> rows) {
  final unique = <String, RecordRow>{};
  for (final row in rows) {
    unique[parseStringValue(row[Fields.id])] = row;
  }
  final result = unique.values.toList();
  sortRecordRowsNewestFirst(result);
  return result;
}

void sortRecordRowsNewestFirst(List<RecordRow> rows) {
  rows.sort(compareRecordRowsNewestFirst);
}
