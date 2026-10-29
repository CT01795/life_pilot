import 'package:life_pilot/utils/record_row_utils.dart'
    show reservedRecordCategory;

/// Pure history-list rules shared by accounting and points. Controllers retain
/// request state; services retain persistence and date-window queries.
class ModelRecordHistory {
  static List<T> ordered<T>(
    Iterable<T> records, {
    required String Function(T) idOf,
    required DateTime Function(T) dateOf,
  }) {
    final unique = <String, T>{};
    for (final record in records) {
      unique[idOf(record)] = record;
    }
    final dated = <(T, DateTime)>[];
    var requiresSort = false;
    for (final record in unique.values) {
      final date = dateOf(record);
      // Equal dates retain the previous sort path and its tie behavior. Inspect
      // the deduplicated order: a replacement can change an earlier row's date.
      if (!requiresSort && dated.isNotEmpty && !dated.last.$2.isAfter(date)) {
        requiresSort = true;
      }
      dated.add((record, date));
    }
    if (requiresSort) dated.sort((a, b) => b.$2.compareTo(a.$2));
    return [for (final item in dated) item.$1];
  }

  /// A latest-record fallback moves the cursor only when every non-reserved
  /// row is older than the requested window. Reserved rows never move it.
  static DateTime fallbackStart<T>(
    Iterable<T> records, {
    required DateTime start,
    required String Function(T) categoryOf,
    required DateTime Function(T) dateOf,
  }) {
    DateTime? latest;
    for (final record in records) {
      if (categoryOf(record) == reservedRecordCategory) continue;
      final date = dateOf(record);
      if (!date.isBefore(start)) return start;
      if (latest == null || date.isAfter(latest)) latest = date;
    }
    return latest ?? start;
  }
}
