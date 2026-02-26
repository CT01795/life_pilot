import 'package:life_pilot/auth/controller_auth.dart';
import 'package:life_pilot/event/model_event_item.dart';
import 'package:life_pilot/event/service_event.dart';
import 'package:life_pilot/utils/date_time.dart';
import 'package:life_pilot/utils/extension.dart';
import 'package:life_pilot/utils/provider_locale.dart';
import 'package:life_pilot/calendar/service_calendar_ok.dart';

import '../utils/logger.dart';

class ModelCalendar {

  List<EventItem> events = [];
  bool isInitialized = false;
  bool _disposed = false;
  // ⭐ 新增：每個月的 flat events cache（避免重複展平）
  final Map<String, List<EventItem>> flatMonthEventsCache = {};
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
    events = list;
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

      for (DateTime current = start;
          !current.isAfter(end);
          current = current.add(Duration(days: 1))) {
        currentWeek.add(current);
        if (currentWeek.length == 7) {
          weeks.add(currentWeek);
          currentWeek = [];
        }
      }
      return weeks;
    });
  }

  Future<List<EventItem>> loadEventsFromService({
    required ServiceEvent serviceEvent,
    required DateTime month,
    required ControllerAuth? auth,
    required ProviderLocale localeProvider,
    required String tableName,
  }) async {
    if (isDisposed) return [];
    try {
      DateTime tmpMonth = DateTimeFormatter.monthOnly(month); // ✅ 加這行
      final user = auth?.currentAccount;
      final locale = localeProvider.locale;
      final weeks = getWeeks(tmpMonth);
      final start = weeks.first.first;
      final end = weeks.last.last;

      final serverEvents = await serviceEvent.getEvents(
          tableName: tableName, dateS: start, dateE: end, inputUser: user);

      final holidays = await ServiceCalendar.fetchHolidays(
          start.subtract(Duration(days: 2)),
          end.add(Duration(days: 2)),
          locale,
          await serviceEvent.getKey(keyName: "GOOGLE_API_KEY"));

      if (isDisposed) return [];

      return [...?serverEvents, ...holidays]
        ..sort((a, b) => a.startDate!.compareTo(b.startDate!));

      //cacheMonthEvents(tmpMonth, events);
      //currentMonth = tmpMonth;
    } catch (e, st) {
      if (!isDisposed) {
        logger.e("❌ loadCalendarEvents error: $e", stackTrace: st);
      }
      rethrow;
    }
  }

  void cacheMonthEvents(DateTime month, List<EventItem> events) {
    final key = month.toMonthKey();
    final weeks = getWeeks(month);
    final tmp = groupEventsByWeekAndDay(weeks: weeks, events: events);
    cachedEvents[key] = tmp;
    flatMonthEventsCache[key] = events.toSet().toList();
  }

  // 依照週、日將事件分組
  Map<int, Map<int, List<EventItem>>> groupEventsByWeekAndDay(
      {required List<List<DateTime>> weeks, required List<EventItem> events}) {
    final Map<int, Map<int, List<EventItem>>> result = {};

    for (int weekIndex = 0; weekIndex < weeks.length; weekIndex++) {
      final week = weeks[weekIndex];

      for (int dayIndex = 0; dayIndex < 7; dayIndex++) {
        final day = week[dayIndex];
        result[weekIndex] ??= {};
        result[weekIndex]![dayIndex] = events.where((event) {
          final start = DateTimeFormatter.dateOnly(event.startDate!);
          final end = DateTimeFormatter.dateOnly(event.endDate ?? start);
          return !day.isBefore(start) && !day.isAfter(end);
        }).toList();
      }
    }

    return result;
  }

// 查詢特定日期的事件
  List<EventItem> getEventsOfDay(DateTime date) {
    final key = date.toMonthKey();
    Map<int, Map<int, List<EventItem>>> weeks = cachedEvents[key] ?? {};

    if (weeks.isEmpty) {
      // 嘗試查前一月或後一月
      final DateTime prev = DateTime(date.year, date.month - 1);
      final DateTime next = DateTime(date.year, date.month + 1);
      if (cachedEvents.containsKey(next.toMonthKey())) {
        weeks = cachedEvents[next.toMonthKey()] ?? {};
      } else if (cachedEvents.containsKey(prev.toMonthKey())) {
        weeks = cachedEvents[prev.toMonthKey()] ?? {};
      }
    }

    if (weeks.isEmpty) return [];

    // 計算該日期在月曆中是第幾週第幾天
    final calendarWeeks = getWeeks(date);
    for (int weekIndex = 0; weekIndex < calendarWeeks.length; weekIndex++) {
      for (int dayIndex = 0; dayIndex < 7; dayIndex++) {
        final day = calendarWeeks[weekIndex][dayIndex];
        if (day.year == date.year &&
            day.month == date.month &&
            day.day == date.day) {
          return weeks[weekIndex]?[dayIndex] ?? [];
        }
      }
    }
    return [];
  }

  void removeEvent(EventItem event) {
    events.removeWhere((e) => e.id == event.id);
    updateCachedEvent(event: event); // 清快取
  }

  // 清除該事件相關月份的快取
  void updateCachedEvent({required EventItem event}) {
    final keysToRemove = <String>{};
    String? startDateS = event.startDate?.toMonthKey();
    String? endDateS = event.endDate?.toMonthKey();

    if (startDateS != null) keysToRemove.add(startDateS);
    if (endDateS != null) keysToRemove.add(endDateS);

    if (event.startDate != null) {
      keysToRemove.add(
          DateTime(event.startDate!.year, event.startDate!.month - 1, 1)
              .toMonthKey());
      keysToRemove.add(
          DateTime(event.startDate!.year, event.startDate!.month + 1, 1)
              .toMonthKey());
    }
    if (event.endDate != null) {
      keysToRemove.add(
          DateTime(event.endDate!.year, event.endDate!.month - 1, 1)
              .toMonthKey());
      keysToRemove.add(
          DateTime(event.endDate!.year, event.endDate!.month + 1, 1)
              .toMonthKey());
    }

    for (var key in keysToRemove) {
      cachedEvents.remove(key);
      flatMonthEventsCache.remove(key);
    }
  }

  void clearAll() {
    events.clear();
    cachedEvents.clear();
    flatMonthEventsCache.clear();
    weeksCache.clear();
  }

  void setMonthFromCache(String key) {
    events = flatMonthEventsCache[key] ?? [];
  }
}