import 'package:life_pilot/event/model_event_item.dart';

/// Locate a date within the SAME grid used to group a month snapshot.
/// Null means outside the grid; an empty list means a known, empty day.
class ModelCalendarDayLookup {
  static List<EventItem>? find({
    required DateTime date,
    required List<List<DateTime>> weeks,
    required Map<int, Map<int, List<EventItem>>> eventsByWeek,
  }) {
    for (var week = 0; week < weeks.length; week++) {
      final days = weeks[week];
      for (var day = 0; day < days.length; day++) {
        final cell = days[day];
        if (cell.year == date.year &&
            cell.month == date.month &&
            cell.day == date.day) {
          return eventsByWeek[week]?[day] ?? const <EventItem>[];
        }
      }
    }
    return null;
  }
}
