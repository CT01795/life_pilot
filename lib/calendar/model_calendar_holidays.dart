import 'package:life_pilot/apps/config_app.dart';
import 'package:life_pilot/event/model_event_item.dart';
import 'package:life_pilot/utils/holidays.dart';
import 'package:life_pilot/utils/value_parser.dart';

class CalendarHolidayRecord {
  const CalendarHolidayRecord({required this.date, required this.summary});
  final DateTime date;
  final String summary;
}

/// Holiday data projection only; requests, caching and ID generation stay out.
class ModelCalendarHolidays {
  /// Calendar-day range: inclusive start and exclusive end, matching projection.
  static List<int> requiredYears(DateTime start, DateTime end) {
    final first = DateTime(start.year, start.month, start.day);
    final until = DateTime(end.year, end.month, end.day);
    if (!until.isAfter(first)) return const [];
    final last = until.subtract(const Duration(days: 1));
    return List.unmodifiable([
      for (var year = first.year; year <= last.year; year++) year,
    ]);
  }

  static List<CalendarHolidayRecord> parseRows(Iterable<dynamic> items) {
    final records = <CalendarHolidayRecord>[];
    for (final item in items) {
      if (item is! Map<String, dynamic>) continue;
      final rawDate = item['date'];
      final summary = item['summary'];
      if (rawDate is! String || summary is! String) continue;
      final date = tryParseDateTimeValue(rawDate);
      if (date == null) continue;
      records.add(
        CalendarHolidayRecord(
          date: DateTime(date.year, date.month, date.day),
          summary: summary,
        ),
      );
    }
    return records;
  }

  static List<EventItem> project({
    required Iterable<CalendarHolidayRecord> records,
    required DateTime start,
    required DateTime end,
    required String Function() createId,
  }) {
    final startDate = DateTime(start.year, start.month, start.day);
    final endDate = DateTime(end.year, end.month, end.day);
    if (!endDate.isAfter(startDate)) return [];
    final ordered = records.toList()..sort((a, b) => a.date.compareTo(b.date));
    final names = <String, ({String name, bool taiwan, bool merge})>{};
    final output = <EventItem>[];
    EventItem? lastMerged;
    for (final record in ordered) {
      if (record.date.isBefore(startDate) || !record.date.isBefore(endDate)) {
        continue;
      }
      final name = names.putIfAbsent(record.summary, () {
        final mapped = CalendarConfig.taiwanHolidays.firstWhere(
          (name) =>
              record.summary.contains(name) && !record.summary.contains('補假'),
          orElse: () => record.summary,
        );
        return (
          name: mapped,
          taiwan: CalendarConfig.taiwanHolidays.any(mapped.contains),
          merge: Holidays.shouldMergeHoliday(mapped),
        );
      });
      if (lastMerged != null && name.merge && lastMerged.name == name.name) {
        lastMerged.endDate = record.date;
      } else {
        final holiday = EventItem(
          id: createId(),
          startDate: record.date,
          endDate: record.date,
          startTime: null,
          endTime: null,
          name: name.name,
          isTaiwanHoliday: name.taiwan,
          isHoliday: true,
        );
        output.add(holiday);
        lastMerged = name.merge ? holiday : null;
      }
    }
    return output;
  }
}
