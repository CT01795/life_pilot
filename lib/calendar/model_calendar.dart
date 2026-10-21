import 'package:life_pilot/event/model_event_item.dart';
import 'package:life_pilot/utils/date_time.dart';
import 'package:life_pilot/utils/extension.dart';
import 'package:life_pilot/calendar/model_calendar_week_layout.dart';
import 'package:life_pilot/calendar/model_calendar_day_grouping.dart';
import 'package:life_pilot/calendar/model_calendar_event_ordering.dart';
import 'package:life_pilot/calendar/model_calendar_day_lookup.dart';

class ModelCalendar {
  List<EventItem> _events = [];
  List<EventItem> get events => _events;

  bool isInitialized = false;
  bool _disposed = false;
  // ⭐ 新增：每個月的 flat events cache（避免重複展平）
  final Map<String, List<EventItem>> flatMonthEventsCache = {};
  final Map<String, ModelCalendarWeekLayout> _weekLayouts = {};
  final Set<String> selectedEventIds = {};
  final Set<String> removedEventIds = {};

  // 月曆快取
  DateTime currentMonth = DateTimeFormatter.dateOnly(DateTime.now());
  // 存放每個月份的「週列表」，避免每次呼叫 getCalendarDays() 都重新計算整個月的日期矩陣。
  final Map<String, List<List<DateTime>>> weeksCache = {};
  // [事件快取結構]：{年月字串 : Map<週索引, Map<日索引, List<Event>>>}
  final Map<String, Map<int, Map<int, List<EventItem>>>> cachedEvents = {};

  bool get isDisposed => _disposed;

  void dispose() {
    _disposed = true;
  }

  // 切換事件選取
  void toggleEventSelection(String eventId, bool isSelected) {
    if (isSelected) {
      selectedEventIds.add(eventId);
    } else {
      selectedEventIds.remove(eventId);
    }
  }

  void markRemoved(String eventId) {
    removedEventIds.add(eventId);
  }

  void setEvents(List<EventItem> list) {
    _events = list;
  }

  List<EventItem> eventsForMonth(DateTime month) {
    return flatMonthEventsCache[month.toMonthKey()] ?? const <EventItem>[];
  }

  List<EventWithRow> eventRowsForWeek(DateTime month, int weekIndex) {
    final weeks = getWeeks(month);
    if (weekIndex < 0 || weekIndex >= weeks.length) return const [];
    final key = month.toMonthKey();
    final source = eventsForMonth(month);
    var layout = _weekLayouts[key];
    if (layout == null || !identical(layout.source, source)) {
      layout = _weekLayouts[key] = ModelCalendarWeekLayout(source);
    }
    return layout.forWeek(weeks[weekIndex].first, weeks[weekIndex].last);
  }

  //--------------------------- 核心方法 ---------------------------
  // 取得完整月曆格子（含上月與下月填充週）
  List<List<DateTime>> getWeeks(DateTime month) {
    final key = month.toMonthKey();
    return weeksCache.putIfAbsent(key, () {
      final first = DateTime(month.year, month.month, 1).toLocal();
      final last = DateTime(month.year, month.month + 1, 0).toLocal();

      final start = first.subtract(Duration(days: first.weekday % 7));
      final end = last.add(Duration(days: 6 - (last.weekday % 7)));

      List<List<DateTime>> weeks = [];
      List<DateTime> currentWeek = [];

      for (
        DateTime current = start;
        !current.isAfter(end);
        current = current.add(const Duration(days: 1))
      ) {
        currentWeek.add(current);
        if (currentWeek.length == 7) {
          weeks.add(currentWeek);
          currentWeek = [];
        }
      }
      return weeks;
    });
  }

  /// Orders a private copy; storage and request orchestration live elsewhere.
  static List<EventItem> orderedEvents(Iterable<EventItem> events) =>
      ModelCalendarEventOrdering.ordered(events);

  void cacheMonthEvents(DateTime month, List<EventItem> inEvents) {
    final key = month.toMonthKey();
    _weekLayouts.remove(key);
    final weeks = getWeeks(month);
    final tmp = groupEventsByWeekAndDay(weeks: weeks, inEvents: inEvents);
    cachedEvents[key] = tmp;
    flatMonthEventsCache[key] = {
      for (var e in inEvents) e.id: e,
    }.values.toList();
  }

  // 依照週、日將事件分組
  Map<int, Map<int, List<EventItem>>> groupEventsByWeekAndDay({
    required List<List<DateTime>> weeks,
    required List<EventItem> inEvents,
  }) {
    return ModelCalendarDayGrouping.group(weeks: weeks, events: inEvents);
  }

  // 查詢特定日期的事件
  List<EventItem> getEventsOfDay(DateTime date) {
    // Prefer the date's own month, then the existing next/previous fallback
    // order. Each event snapshot must be paired with its own calendar grid.
    for (final month in [
      date,
      DateTime(date.year, date.month + 1),
      DateTime(date.year, date.month - 1),
    ]) {
      final grouped = cachedEvents[month.toMonthKey()];
      if (grouped == null || grouped.isEmpty) continue;
      final events = ModelCalendarDayLookup.find(
        date: date,
        weeks: getWeeks(month),
        eventsByWeek: grouped,
      );
      if (events != null) return events;
    }
    return [];
  }

  void removeEvent(EventItem event) {
    _events.removeWhere((e) => e.id == event.id);
    updateCachedEvent(event: event); // 清快取
  }

  // 清除該事件相關月份的快取
  void updateCachedEvent({required EventItem event}) {
    invalidateEventRange(startDate: event.startDate, endDate: event.endDate);
  }

  void invalidateEventRange({required DateTime? startDate, DateTime? endDate}) {
    if (startDate == null && endDate == null) return;

    var first = startDate ?? endDate!;
    var last = endDate ?? startDate!;
    if (last.isBefore(first)) {
      final swap = first;
      first = last;
      last = swap;
    }

    var month = DateTime(first.year, first.month - 1);
    final lastAffectedMonth = DateTime(last.year, last.month + 1);
    final keysToRemove = <String>{};
    while (!month.isAfter(lastAffectedMonth)) {
      keysToRemove.add(month.toMonthKey());
      month = DateTime(month.year, month.month + 1);
    }

    for (var key in keysToRemove) {
      cachedEvents.remove(key);
      flatMonthEventsCache.remove(key);
      _weekLayouts.remove(key);
    }
  }

  void clearAll() {
    _events.clear();
    cachedEvents.clear();
    flatMonthEventsCache.clear();
    _weekLayouts.clear();
    weeksCache.clear();
  }

  void setMonthFromCache(String key) {
    _events = flatMonthEventsCache[key] ?? [];
  }
}
