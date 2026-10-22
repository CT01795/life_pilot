import 'package:life_pilot/event/model_event_item.dart';
import 'package:life_pilot/utils/const.dart';
import 'package:life_pilot/utils/date_time.dart';
import 'package:life_pilot/utils/value_parser.dart';

/// Filter lightweight row fields before decoding descriptions/sub-events.
class ModelLocalEventQuery {
  static DateTime? _startDate(Map<String, dynamic> row) =>
      tryParseDateTimeValue(row[EventFields.startDate]);

  /// Stop at the first eligible date; never decode event content for metadata.
  static bool hasRowsBefore(
    Iterable<Map<String, dynamic>> rows,
    DateTime before,
  ) {
    for (final row in rows) {
      final date = _startDate(row);
      if (date != null && date.isBefore(before)) return true;
    }
    return false;
  }

  /// Finds the fallback row in one pass, without sorting or decoding history.
  static Map<String, dynamic>? latestRowBefore(
    Iterable<Map<String, dynamic>> rows,
    DateTime before,
  ) {
    Map<String, dynamic>? latest;
    DateTime? latestDate;
    for (final row in rows) {
      final date = _startDate(row);
      if (date == null || !date.isBefore(before)) continue;
      if (latestDate == null || date.isAfter(latestDate)) {
        latestDate = date;
        latest = row;
      }
    }
    return latest;
  }

  static List<EventItem> select(
    List<Map<String, dynamic>> rows, {
    required DateTime start,
    required DateTime end,
    String? id,
    int offset = 0,
    int? limit,
    bool Function()? shouldContinue,
  }) => iterate(
    rows,
    start: start,
    end: end,
    id: id,
    offset: offset,
    limit: limit,
    shouldContinue: shouldContinue,
  ).toList();

  static Iterable<EventItem> iterate(
    List<Map<String, dynamic>> rows, {
    required DateTime start,
    required DateTime end,
    String? id,
    int offset = 0,
    int? limit,
    bool Function()? shouldContinue,
  }) {
    final from = DateTimeFormatter.dateOnly(start);
    final through = DateTimeFormatter.dateOnly(end);
    return _matchingRows(rows, from, through, id, shouldContinue)
        .skip(offset)
        .take(limit ?? rows.length)
        .map((row) => EventItem.fromJson(json: row));
  }

  static Iterable<Map<String, dynamic>> _matchingRows(
    List<Map<String, dynamic>> rows,
    DateTime from,
    DateTime through,
    String? id,
    bool Function()? shouldContinue,
  ) sync* {
    // Traversal-local, one-entry memo: repeated date strings need not be parsed
    // again. A fresh iteration resets it, including after in-place row edits.
    String? previousDate;
    bool? previousMatch;
    for (final row in rows) {
      // Test scope before touching row fields or decoding the next event.
      // Consumers must discard incomplete output after cancellation.
      if (shouldContinue?.call() == false) return;
      if (id != null && id.isNotEmpty) {
        if (row[Fields.id] == id) yield row;
        continue;
      }
      final String? rawDate = row[EventFields.startDate];
      if (previousMatch == null || rawDate != previousDate) {
        final date = EventItem.fromStringOrNull(rawDate);
        final day = date == null
            ? null
            : DateTimeFormatter.dateOnly(date.toLocal());
        previousMatch =
            day == null || (!day.isBefore(from) && !day.isAfter(through));
        previousDate = rawDate;
      }
      if (previousMatch) yield row;
    }
  }
}
