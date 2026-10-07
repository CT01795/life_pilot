import 'package:life_pilot/utils/const.dart';

typedef RecordRow = Map<String, dynamic>;

const String reservedRecordCategory = 'reserved';

DateTime recordDayUpperBound(DateTime date) =>
    DateTime(date.year, date.month, date.day + 1);

DateTime? recordRowDate(RecordRow row) =>
    DateTime.tryParse(row['date']?.toString() ?? '');

bool isReservedRecordRow(RecordRow row) =>
    row['primary_category'] == reservedRecordCategory;

bool recordRowMatchesAccountAndType(
  RecordRow row, {
  required String accountId,
  required String type,
}) =>
    row['account_id']?.toString() == accountId &&
    row['type']?.toString().toLowerCase() == type.toLowerCase();

RecordRow? latestRecordRowWhere(
  Iterable<RecordRow> rows,
  bool Function(RecordRow row) matches,
) {
  final matching = rows.where(matches).toList();
  sortRecordRowsNewestFirst(matching);
  return matching.isEmpty ? null : matching.first;
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
    latestRecordRowWhere(rows, (row) => row['event_id']?.toString() == eventId);

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
    final fallback = source.where((row) => !isReservedRecordRow(row)).toList();
    sortRecordRowsNewestFirst(fallback);
    if (fallback.isNotEmpty) filtered.add(fallback.first);
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
    unique[row[Fields.id].toString()] = row;
  }
  final result = unique.values.toList();
  sortRecordRowsNewestFirst(result);
  return result;
}

void sortRecordRowsNewestFirst(List<RecordRow> rows) {
  rows.sort(
    (a, b) =>
        (b['date']?.toString() ?? '').compareTo(a['date']?.toString() ?? ''),
  );
}
