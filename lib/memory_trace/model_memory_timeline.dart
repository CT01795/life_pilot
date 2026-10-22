import 'package:life_pilot/event/model_event_item.dart';

typedef MemoryTimelineHeader = ({DateTime date, bool month, bool day});

/// Counts the currently displayed records only. No storage, formatting or UI.
/// Rebuild after edits; EventItem itself is mutable.
class ModelMemoryTimeline {
  final Map<int, int> daily;
  final Map<int, int> monthly;
  final int memoryCount;
  final int cityCount;
  final Map<int, MemoryTimelineHeader> _headers;
  int get dayCount => daily.length;

  ModelMemoryTimeline._({
    required Map<int, int> daily,
    required Map<int, int> monthly,
    required this.memoryCount,
    required this.cityCount,
    required Map<int, MemoryTimelineHeader> headers,
  }) : daily = Map.unmodifiable(daily),
       monthly = Map.unmodifiable(monthly),
       _headers = Map.unmodifiable(headers);

  /// Only boundaries are stored; ordinary cards need no extra date metadata.
  MemoryTimelineHeader? headerAt(int index) => _headers[index];

  factory ModelMemoryTimeline.fromEvents(Iterable<EventBase> events) {
    final daily = <int, int>{};
    final monthly = <int, int>{};
    final normalizedCities = <String, String>{};
    final cities = <String>{};
    final headers = <int, MemoryTimelineHeader>{};
    int? previousDay;
    int? previousMonth;
    var count = 0;
    for (final event in events) {
      count++;
      final date = event.startDate;
      if (date == null) {
        previousDay = null;
        previousMonth = null;
        continue;
      }
      final day = _dayKey(date);
      final month = _monthKey(date);
      if (previousDay != day) {
        headers[count - 1] = (
          date: date,
          month: previousMonth != month,
          day: true,
        );
      }
      previousDay = day;
      previousMonth = month;
      daily[day] = (daily[day] ?? 0) + 1;
      monthly[month] = (monthly[month] ?? 0) + 1;
      final rawCity = event.city;
      final city = normalizedCities.putIfAbsent(
        rawCity,
        () => rawCity.trim().toLowerCase(),
      );
      if (city.isNotEmpty) cities.add(city);
    }
    return ModelMemoryTimeline._(
      daily: daily,
      monthly: monthly,
      memoryCount: count,
      cityCount: cities.length,
      headers: headers,
    );
  }

  int countForDay(DateTime date, {int fallback = 0}) =>
      daily[_dayKey(date)] ?? fallback;
  int countForMonth(DateTime date, {int fallback = 0}) =>
      monthly[_monthKey(date)] ?? fallback;
  static int _dayKey(DateTime date) =>
      date.year * 10000 + date.month * 100 + date.day;
  static int _monthKey(DateTime date) => date.year * 100 + date.month;
}
