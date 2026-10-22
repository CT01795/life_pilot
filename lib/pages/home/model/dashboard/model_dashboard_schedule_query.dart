import 'package:life_pilot/pages/home/model/event/calendar_event.dart';
import 'package:life_pilot/utils/value_parser.dart';

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
      rows.map(CalendarEvent.fromJson).toList()..sort(_compare);

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

  static int _compare(CalendarEvent left, CalendarEvent right) {
    var comparison = (left.startDate ?? DateTime(9999)).compareTo(
      right.startDate ?? DateTime(9999),
    );
    if (comparison != 0) return comparison;
    final leftTime = left.startTime;
    final rightTime = right.startTime;
    comparison =
        (leftTime == null ? 24 * 60 : leftTime.hour * 60 + leftTime.minute)
            .compareTo(
              rightTime == null
                  ? 24 * 60
                  : rightTime.hour * 60 + rightTime.minute,
            );
    if (comparison != 0) return comparison;
    comparison = (left.city ?? '').compareTo(right.city ?? '');
    if (comparison != 0) return comparison;
    comparison = (left.location ?? '').compareTo(right.location ?? '');
    return comparison != 0 ? comparison : left.name.compareTo(right.name);
  }
}
