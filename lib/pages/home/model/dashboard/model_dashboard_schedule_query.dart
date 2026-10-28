import 'package:life_pilot/pages/home/model/event/calendar_event.dart';
import 'package:life_pilot/utils/value_parser.dart';
import 'package:life_pilot/pages/home/model/dashboard/model_dashboard_event_ordering.dart';

/// Pure projection for the dashboard's three-day schedule window.
/// Filter lightweight fields before decoding descriptions or sub-events.
class ModelDashboardScheduleQuery {
  final DateTime today;
  final DateTime rangeEnd;

  ModelDashboardScheduleQuery(DateTime now)
    : today = DateTime(now.year, now.month, now.day),
      rangeEnd = DateTime(
        now.year,
        now.month,
        now.day,
      ).add(const Duration(days: 3));

  List<CalendarEvent> selectLocal(Iterable<Map<String, dynamic>> rows) =>
      decodeRows(rows.where(_matchesWindow));

  List<CalendarEvent> decodeRows(Iterable<Map<String, dynamic>> rows) =>
      ModelDashboardEventOrdering.sorted(
        rows.map(CalendarEvent.fromJson),
        keyOf: (event) {
          final time = event.startTime;
          return DashboardEventOrderKey(
            date: event.startDate,
            minutes: time == null ? 1440 : time.hour * 60 + time.minute,
            city: event.city,
            location: event.location,
            name: event.name,
          );
        },
      );

  bool _matchesWindow(Map<String, dynamic> row) {
    if (row['is_completed'] == true) return false;
    final start = tryParseDateTimeValue(
      parseStringValue(row['start_date']),
      toLocal: true,
    );
    // A future start cannot intersect this window, regardless of its end.
    if (start == null || !start.isBefore(rangeEnd)) return false;
    final end = tryParseDateTimeValue(
      parseStringValue(row['end_date']),
      toLocal: true,
    );
    return !(end ?? start).isBefore(today);
  }
}
