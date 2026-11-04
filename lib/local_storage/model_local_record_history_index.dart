import 'package:life_pilot/utils/record_row_utils.dart';

/// Read-only history metadata for one account/type snapshot.
class ModelLocalRecordHistoryIndex {
  ModelLocalRecordHistoryIndex(
    Iterable<RecordRow> rows, {
    required String accountId,
    required String type,
  }) {
    for (final row in rows) {
      if (!recordRowMatchesAccountAndType(
        row,
        accountId: accountId,
        type: type,
      )) {
        continue;
      }
      if (_latest == null || compareRecordRowsNewestFirst(row, _latest!) < 0) {
        _latest = row;
      }
      if (!isReservedRecordRow(row)) {
        final date = recordRowDate(row);
        if (date != null) _dates.add(date);
      }
    }
    _dates.sort();
  }

  final _dates = <DateTime>[];
  RecordRow? _latest;
  RecordRow? get latest => _latest;

  bool hasBefore(DateTime before) =>
      _dates.isNotEmpty && _dates.first.isBefore(before);

  DateTime? latestBefore(DateTime before) {
    var low = 0;
    var high = _dates.length;
    while (low < high) {
      final mid = (low + high) ~/ 2;
      if (_dates[mid].isBefore(before)) {
        low = mid + 1;
      } else {
        high = mid;
      }
    }
    return low == 0 ? null : _dates[low - 1].toLocal();
  }
}
