import 'package:life_pilot/event/model_event_item.dart';
import 'package:life_pilot/utils/const.dart';
import 'package:life_pilot/utils/date_time.dart';

/// Filter lightweight row fields before decoding descriptions/sub-events.
class ModelLocalEventQuery {
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
