import 'package:life_pilot/event/model_event_item.dart';
import 'package:life_pilot/utils/date_time.dart';

/// Calendar-grid projection only. Keeps source order inside each day and never
/// changes the source events or the caller's week layout.
class ModelCalendarDayGrouping {
  static Map<int, Map<int, List<EventItem>>> group({
    required List<List<DateTime>> weeks,
    required List<EventItem> events,
  }) {
    final result = <int, Map<int, List<EventItem>>>{};
    final cells = <({DateTime date, int week, int day})>[];
    for (var week = 0; week < weeks.length; week++) {
      result[week] = {};
      for (var day = 0; day < 7; day++) {
        result[week]![day] = [];
        cells.add((date: weeks[week][day], week: week, day: day));
      }
    }
    if (cells.isEmpty) return result;
    cells.sort((a, b) => a.date.compareTo(b.date));

    // One range only, scoped to this projection. Consecutive same-day events
    // share their cell bounds without retaining events across edits/accounts.
    DateTime? previousStart, previousEnd;
    var firstCell = 0, afterLastCell = 0;
    for (final event in events) {
      final start = DateTimeFormatter.dateOnly(event.startDate!);
      final endDate = event.endDate;
      final end = endDate == null ? start : DateTimeFormatter.dateOnly(endDate);
      if (previousStart != start || previousEnd != end) {
        var low = 0;
        var high = cells.length;
        while (low < high) {
          final middle = low + ((high - low) ~/ 2);
          if (cells[middle].date.isBefore(start)) {
            low = middle + 1;
          } else {
            high = middle;
          }
        }
        firstCell = low;
        afterLastCell = low;
        while (afterLastCell < cells.length &&
            !cells[afterLastCell].date.isAfter(end)) {
          afterLastCell++;
        }
        previousStart = start;
        previousEnd = end;
      }
      for (var i = firstCell; i < afterLastCell; i++) {
        final cell = cells[i];
        result[cell.week]![cell.day]!.add(event);
      }
    }
    return result;
  }
}
