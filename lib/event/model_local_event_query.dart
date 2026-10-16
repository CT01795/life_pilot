import 'package:life_pilot/event/model_event_item.dart';
import 'package:life_pilot/utils/const.dart';
import 'package:life_pilot/utils/date_time.dart';
import 'package:life_pilot/utils/value_parser.dart';

/// Filter lightweight row fields before decoding descriptions/sub-events.
class ModelLocalEventQuery {
  /// Finds the fallback row in one pass, without sorting or decoding history.
  static Map<String, dynamic>? latestRowBefore(
    Iterable<Map<String, dynamic>> rows,
    DateTime before,
  ) {
    Map<String, dynamic>? latest;
    DateTime? latestDate;
    for (final row in rows) {
      final date = tryParseDateTimeValue(
        parseStringValue(row[EventFields.startDate]),
      );
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
  }) => iterate(
    rows,
    start: start,
    end: end,
    id: id,
    offset: offset,
    limit: limit,
  ).toList();

  static Iterable<EventItem> iterate(
    List<Map<String, dynamic>> rows, {
    required DateTime start,
    required DateTime end,
    String? id,
    int offset = 0,
    int? limit,
  }) {
    final from = DateTimeFormatter.dateOnly(start);
    final through = DateTimeFormatter.dateOnly(end);
    return rows
        .where((row) {
          if (id != null && id.isNotEmpty) return row[Fields.id] == id;
          final date = EventItem.fromStringOrNull(row[EventFields.startDate]);
          if (date == null) return true;
          final day = DateTimeFormatter.dateOnly(date.toLocal());
          return !day.isBefore(from) && !day.isAfter(through);
        })
        .skip(offset)
        .take(limit ?? rows.length)
        .map((row) => EventItem.fromJson(json: row));
  }
}
