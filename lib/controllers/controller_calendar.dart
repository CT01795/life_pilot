import 'package:flutter/material.dart' hide Notification;
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/models/model_event.dart';
import 'package:life_pilot/notification/notification.dart';
import 'package:life_pilot/services/service_holiday.dart';
import 'package:life_pilot/services/service_storage.dart';
import 'package:life_pilot/utils/utils_const.dart';
import 'package:life_pilot/utils/utils_enum.dart';
import 'package:uuid/uuid.dart';

class ControllerCalendar extends ChangeNotifier {
  final ServiceStorage service = ServiceStorage();
  final String tableName;

  late DateTime currentMonth;

  ControllerCalendar({required this.tableName}) {
    currentMonth = DateUtils.dateOnly(DateTime.now());
  }

  List<Event> events = [];
  bool isLoading = false; // ⬅️ 新增 loading 旗標

  // 給 PageView 初始用的基準年月
  static DateTime baseDate = DateTime(1911, 1);

  int get initialPage {
    return (currentMonth.year - baseDate.year) * 12 + (currentMonth.month - 1);
  }

  // [事件快取結構]：{年月字串 : Map<週索引, Map<日索引, List<Event>>>}
  final Map<String, Map<int, Map<int, List<Event>>>> _cachedEvents = {};

  Map<int, List<EventWithRow>> getWeekEventRows(DateTime month) {
    final calendarWeeks = getCalendarDays(month);
    final weekEventRows = <int, List<EventWithRow>>{};

    for (int weekIndex = 0; weekIndex < calendarWeeks.length; weekIndex++) {
      final week = calendarWeeks[weekIndex];
      final weekStart = week.first;
      final weekEnd = week.last;

      final eventsThisWeek = events.where((event) {
        final start = DateUtils.dateOnly(event.startDate!);
        final end = DateUtils.dateOnly(event.endDate ?? event.startDate!);
        return !(end.isBefore(weekStart) || start.isAfter(weekEnd));
      }).toList();

      final List<List<Event>> rows = [];

      for (final event in eventsThisWeek) {
        bool placed = false;

        for (final row in rows) {
          if (!row.any((e) => isOverlapping(e, event))) {
            row.add(event);
            placed = true;
            break;
          }
        }

        if (!placed) {
          rows.add([event]);
        }
      }

      final List<EventWithRow> layered = [];

      for (int i = 0; i < rows.length; i++) {
        for (final e in rows[i]) {
          layered.add(EventWithRow(event: e, rowIndex: i));
        }
      }

      weekEventRows[weekIndex] = layered;
    }

    return weekEventRows;
  }

  // 工具方法：檢查兩個事件是否跨日重疊
  bool isOverlapping(Event a, Event b) {
    final aStart = DateUtils.dateOnly(a.startDate!);
    final aEnd = DateUtils.dateOnly(a.endDate ?? a.startDate!);
    final bStart = DateUtils.dateOnly(b.startDate!);
    final bEnd = DateUtils.dateOnly(b.endDate ?? b.startDate!);

    return !(aEnd.isBefore(bStart) || aStart.isAfter(bEnd));
  }


  List<List<DateTime>> getCalendarDays(DateTime month) {
    final firstDayOfMonth = DateTime(month.year, month.month, 1);
    final lastDayOfMonth = DateTime(month.year, month.month + 1, 0);

    int startOffset = firstDayOfMonth.weekday % 7;
    DateTime startDate = firstDayOfMonth.subtract(Duration(days: startOffset));

    int endOffset = 6 - (lastDayOfMonth.weekday % 7);
    DateTime endDate = lastDayOfMonth.add(Duration(days: endOffset));

    List<List<DateTime>> weeks = [];
    List<DateTime> currentWeek = [];

    for (DateTime date = startDate;
        !date.isAfter(endDate);
        date = date.add(Duration(days: 1))) {
      currentWeek.add(date);
      if (currentWeek.length == 7) {
        weeks.add(currentWeek);
        currentWeek = [];
      }
    }

    return weeks;
  }

  Future<void> loadEvents() async {
    if (isLoading) return; // 防止重複執行

    isLoading = true;
    notifyListeners(); // 通知 View 更新

    try {
      final calendarWeeks = getCalendarDays(currentMonth);
      DateTime start = calendarWeeks.first.first;
      DateTime end = calendarWeeks.last.last;

      // 1. 先從服務端拉事件
      final allEvents =
          await service.getRecommendedEvents(tableName: tableName, dateS: start, dateE: end);
      events = allEvents ?? []; // ✅ 更新 List<Event> 給 UI 使用

      // 2. 再呼叫 HolidayService 抓假日事件
      final holidays = await HolidayService.fetchHolidays(start.subtract(Duration(days:2)), end.add(Duration(days:2)));
      events.addAll(holidays);

      // 3. 排序（選擇性，依需求排序事件）
    events.sort((a, b) => a.startDate!.compareTo(b.startDate!));

      // ✅ 分組儲存進快取
      _cachedEvents[_monthKey(currentMonth)] =
          _groupEventsByWeekAndDay(calendarWeeks, events);
    } catch (e) {
      rethrow;
    } finally {
      isLoading = false;
      notifyListeners(); // 通知 View 更新
    }
  }

  Map<int, Map<int, List<Event>>> _groupEventsByWeekAndDay(
      List<List<DateTime>> weeks, List<Event> events) {
    final Map<int, Map<int, List<Event>>> result = {};

    for (int weekIndex = 0; weekIndex < weeks.length; weekIndex++) {
      final week = weeks[weekIndex];

      for (int dayIndex = 0; dayIndex < 7; dayIndex++) {
        final day = week[dayIndex];
        result[weekIndex] ??= {};
        result[weekIndex]![dayIndex] = events.where((event) {
          final start = event.startDate!;
          final end = event.endDate ?? start;
          return !day.isBefore(start) && !day.isAfter(end);
        }).toList();
      }
    }

    return result;
  }

  String _monthKey(DateTime date) =>
      "${date.year}-${date.month.toString().padLeft(2, constZero)}";

  Future<void> goToMonth(DateTime newMonth) async {
    currentMonth = newMonth;
    final key = _monthKey(newMonth);
    if (_cachedEvents.containsKey(key)) {
      // ✅ 同步更新 events（這是你缺的）
      final allCached = _cachedEvents[key]!;
      final allEvents = <Event>[];

      for (var week in allCached.values) {
        for (var dayEvents in week.values) {
          allEvents.addAll(dayEvents);
        }
      }

      // 移除重複事件
      events = allEvents.toSet().toList();

      notifyListeners(); // 更新畫面
    } else {
      await loadEvents();
    }
  }

  Future<void> goToToday(PageController controller) async {
    currentMonth = DateUtils.dateOnly(DateTime.now());
    await goToMonth(currentMonth);
  }

  Future<void> goToPreviousMonth(PageController controller) async {
    currentMonth = DateTime(currentMonth.year, currentMonth.month - 1);
    await goToMonth(currentMonth);
  }

  Future<void> goToNextMonth(PageController controller) async {
    currentMonth = DateTime(currentMonth.year, currentMonth.month + 1);
    await goToMonth(currentMonth);
  }

  List<Event> getEventsOfDay(DateTime date) {
    final key = _monthKey(date);
    final weeks = _cachedEvents[key];
    if (weeks == null) return [];

    // 計算該日期在月曆中是第幾週第幾天
    final calendarWeeks = getCalendarDays(date);
    for (int weekIndex = 0; weekIndex < calendarWeeks.length; weekIndex++) {
      final week = calendarWeeks[weekIndex];
      for (int dayIndex = 0; dayIndex < 7; dayIndex++) {
        if (week[dayIndex].year == date.year &&
            week[dayIndex].month == date.month &&
            week[dayIndex].day == date.day) {
          return weeks[weekIndex]?[dayIndex] ?? [];
        }
      }
    }

    return [];
  }

  void updateCachedEvent(Event oldEvent, Event newEvent) {
    final oldStartDateS = oldEvent.startDate != null ? _monthKey(oldEvent.startDate!) : null; // e.g., '2025-09'
    final newStartDateS = newEvent.startDate != null ? _monthKey(newEvent.startDate!) : null;

    final oldEndDateS = oldEvent.endDate != null ? _monthKey(oldEvent.endDate!) : null; // e.g., '2025-09'
    final newEndDateS = newEvent.endDate != null ? _monthKey(newEvent.endDate!) : null;

    // 移除快取
    if (oldStartDateS != null && _cachedEvents.containsKey(oldStartDateS)) {
      _cachedEvents.remove(oldStartDateS);
    }
    if (newStartDateS != null && _cachedEvents.containsKey(newStartDateS)) {
      _cachedEvents.remove(newStartDateS);
    }
    if (oldEndDateS != null && _cachedEvents.containsKey(oldEndDateS)) {
      _cachedEvents.remove(oldEndDateS);
    }
    if (newEndDateS != null && _cachedEvents.containsKey(newEndDateS)) {
      _cachedEvents.remove(newEndDateS);
    }
  }

  Future<void> checkAndGenerateNextEvents(BuildContext context) async {
    final loc = AppLocalizations.of(context)!;
    final DateTime today = DateTime.now();

    for (final event in events) {
      final repeat = event.repeatOptions;
      if (repeat == RepeatRule.once) continue;

      final DateTime startDate = event.startDate!;
      
      // 如果今天已經是事件發生日，就生成下一個
      if (!isSameDay(today, startDate)) continue;

      final DateTime nextStart = repeat.getNextDate(startDate);
      final DateTime? nextEnd = event.endDate != null
          ? repeat.getNextDate(event.endDate!)
          : null;

      final newEvent = event.copyWith(
        newId: Uuid().v4(),
        newStartDate: nextStart,
        newEndDate: nextEnd,
      );

      await service.saveRecommendedEvent(context, newEvent, true, tableName);
      await MyCustomNotification.scheduleEventReminders(loc, newEvent, tableName);

      // 更新舊事件的 repeatOption 為 'once'
      final updatedOldEvent = event.copyWith(newRepeatOptions: RepeatRule.once, // 更新 repeatOptions
      );

      // 儲存更新後的舊事件
      await service.saveRecommendedEvent(context, updatedOldEvent, false, tableName);
    }

    await loadEvents();
  }

  // 判斷是否為同一天
  bool isSameDay(DateTime a, DateTime b) {
    return (a.year == b.year && a.month == b.month && a.day == b.day);
  }
}

class EventWithRow {
  final Event event;
  final int rowIndex;

  EventWithRow({required this.event, required this.rowIndex});
}
