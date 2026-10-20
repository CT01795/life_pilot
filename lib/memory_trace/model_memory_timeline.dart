import 'package:life_pilot/event/model_event_item.dart';

/// Counts the currently displayed records only. No storage, formatting or UI.
/// Rebuild after edits; EventItem itself is mutable.
class ModelMemoryTimeline {
  final Map<int, int> daily;
  final Map<int, int> monthly;
  final int memoryCount;
  final int cityCount;
  int get dayCount => daily.length;

  ModelMemoryTimeline._({
    required Map<int, int> daily,
    required Map<int, int> monthly,
    required this.memoryCount,
    required this.cityCount,
  }) : daily = Map.unmodifiable(daily),
       monthly = Map.unmodifiable(monthly);

  factory ModelMemoryTimeline.fromEvents(Iterable<EventBase> events) {
    final daily = <int, int>{};
    final monthly = <int, int>{};
    final normalizedCities = <String, String>{};
    final cities = <String>{};
    var count = 0;
    for (final event in events) {
      count++;
      final date = event.startDate;
      if (date == null) continue;
      final day = _dayKey(date);
      final month = _monthKey(date);
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
