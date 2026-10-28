import 'package:life_pilot/event/model_event_item.dart';

typedef MemoryTimelineHeader = ({DateTime date, bool month, bool day});

/// Counts the currently displayed records only. No storage, formatting or UI.
/// Rebuild after edits; EventItem itself is mutable.
class ModelMemoryTimeline {
  static final _snapshots = Expando<ModelMemoryTimeline>();

  /// Reuses a projection for an unchanged display-list snapshot. Replace the
  /// list after edits; mutable event fields cannot invalidate an identity key.
  static ModelMemoryTimeline forSnapshot(List<EventItem> events) =>
      _snapshots[events] ??= ModelMemoryTimeline.fromEvents(events);

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
    int? pendingDay;
    var pendingMonth = 0, pendingCount = 0;
    // Timelines commonly contain many adjacent records from the same day.
    // Flush one run, rather than looking up and writing both maps per record.
    // This state belongs to this projection only, never a retained snapshot.
    void flushCounts() {
      final day = pendingDay;
      if (day == null) return;
      daily[day] = (daily[day] ?? 0) + pendingCount;
      monthly[pendingMonth] = (monthly[pendingMonth] ?? 0) + pendingCount;
      pendingCount = 0;
    }

    var count = 0;
    for (final event in events) {
      count++;
      final date = event.startDate;
      if (date == null) {
        previousDay = null;
        previousMonth = null;
        continue;
      }
      final month = _monthKey(date);
      final day = month * 100 + date.day;
      if (previousDay != day) {
        headers[count - 1] = (
          date: date,
          month: previousMonth != month,
          day: true,
        );
      }
      previousDay = day;
      previousMonth = month;
      if (pendingDay != day) {
        flushCounts();
        pendingDay = day;
        pendingMonth = month;
      }
      pendingCount++;
      final rawCity = event.city;
      final city = normalizedCities.putIfAbsent(
        rawCity,
        () => rawCity.trim().toLowerCase(),
      );
      if (city.isNotEmpty) cities.add(city);
    }
    flushCounts();
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
