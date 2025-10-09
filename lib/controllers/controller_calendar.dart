import 'package:flutter/material.dart' hide Notification, DateUtils;
import 'package:life_pilot/controllers/controller_auth.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/utils/core/utils_locator.dart';
import 'package:life_pilot/models/model_event_item.dart';
import 'package:life_pilot/notification/notification_entry.dart';
import 'package:life_pilot/providers/provider_locale.dart';
import 'package:life_pilot/services/calendar/service_holiday.dart';
import 'package:life_pilot/services/service_storage.dart';
import 'package:life_pilot/utils/core/utils_const.dart';
import 'package:life_pilot/utils/utils_date_time.dart';
import 'package:life_pilot/utils/core/utils_enum.dart';
import 'package:uuid/uuid.dart';

class ControllerCalendar extends ChangeNotifier {
  final String tableName;

  late DateTime currentMonth;
  List<EventItem> events = [];
  bool isLoading = false; // ⬅️ 新增 loading 旗標

  // 給 PageView 初始用的基準年月
  static final DateTime baseDate = DateTime(1911, 1);

  int get pageIndex =>
      (currentMonth.year - baseDate.year) * 12 + (currentMonth.month - 1);

  DateTime pageIndexToMonth({required int index}) {
    final year = baseDate.year + (index ~/ 12);
    final month = (index % 12) + 1;
    return DateTime(year, month);
  }

  // [事件快取結構]：{年月字串 : Map<週索引, Map<日索引, List<Event>>>}
  final Map<String, Map<int, Map<int, List<EventItem>>>> _cachedEvents = {};

  ControllerCalendar({required this.tableName}) {
    currentMonth = DateUtils.dateOnly(DateTime.now());
  }

  void clearAll() {
    events.clear();
    _cachedEvents.clear();
    isLoading = false;
    notifyListeners(); // 清除畫面
  }

  // 將日期轉為 key 格式 yyyy-MM
  String _monthKey(DateTime date) =>
      "${date.year}-${date.month.toString().padLeft(2, constZero)}";

  // 取得完整月曆格子（含上月與下月填充週）
  List<List<DateTime>> getCalendarDays({required DateTime month}) {
    final firstDayOfMonth = DateTime(month.year, month.month, 1);
    final lastDayOfMonth = DateTime(month.year, month.month + 1, 0);

    final int startOffset = firstDayOfMonth.weekday % 7;
    final DateTime startDate =
        firstDayOfMonth.subtract(Duration(days: startOffset));

    final int endOffset = 6 - (lastDayOfMonth.weekday % 7);
    final DateTime endDate = lastDayOfMonth.add(Duration(days: endOffset));

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

  // 工具方法：檢查兩個事件是否跨日重疊
  bool isOverlapping({required EventItem a, required EventItem b}) {
    final aStart = DateUtils.dateOnly(a.startDate!);
    final aEnd = DateUtils.dateOnly(a.endDate ?? a.startDate!);
    final bStart = DateUtils.dateOnly(b.startDate!);
    final bEnd = DateUtils.dateOnly(b.endDate ?? b.startDate!);

    return !(aEnd.isBefore(bStart) || aStart.isAfter(bEnd));
  }

  // 拿到該月每週對應的事件層級（含排版 rowIndex）
  Map<int, List<EventWithRow>> getWeekEventRows({required DateTime month}) {
    final calendarWeeks = getCalendarDays(month: month);
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

      final List<List<EventItem>> rows = [];

      for (final event in eventsThisWeek) {
        bool placed = false;

        for (final row in rows) {
          if (!row.any((e) => isOverlapping(a: e, b: event))) {
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

  // 載入月曆事件（含服務端與假日）
  Future<void> loadCalendarEvents({bool notify = true}) async {
    if (isLoading) return; // 防止重複執行

    isLoading = true;
    if (notify) notifyListeners();

    try {
      final ServiceStorage service = getIt<ServiceStorage>();
      final ControllerAuth auth = getIt<ControllerAuth>();
      final ProviderLocale localeProvider = getIt<ProviderLocale>();
      final user = auth.currentAccount;
      final locale = localeProvider.locale;
      final calendarWeeks = getCalendarDays(month: currentMonth);
      final DateTime start = calendarWeeks.first.first;
      final DateTime end = calendarWeeks.last.last;

      // 1. 先從服務端拉事件
      final allEvents = await service.getEvents(
          tableName: tableName, dateS: start, dateE: end, inputUser: user);
      events = allEvents ?? []; // ✅ 更新 List<Event> 給 UI 使用

      // 2. 再呼叫 HolidayService 抓假日事件
      final holidays = await HolidayService.fetchHolidays(
          start.subtract(Duration(days: 2)),
          end.add(Duration(days: 2)),
          locale);
      events.addAll(holidays);

      // 3. 排序（選擇性，依需求排序事件）
      events.sort((a, b) => a.startDate!.compareTo(b.startDate!));

      // ✅ 分組儲存進快取
      _cachedEvents[_monthKey(currentMonth)] =
          _groupEventsByWeekAndDay(weeks: calendarWeeks, events: events);
    } catch (e) {
      rethrow;
    } finally {
      isLoading = false;
      if (notify) {
        notifyListeners(); // 通知 View 更新
      }
    }
  }

  // 依照週、日將事件分組
  Map<int, Map<int, List<EventItem>>> _groupEventsByWeekAndDay(
      {required List<List<DateTime>> weeks, required List<EventItem> events}) {
    final Map<int, Map<int, List<EventItem>>> result = {};

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

  // 跳轉月並同步資料（若有快取則不重新拉）
  Future<void> goToMonth({required DateTime month, bool notify = true}) async {
    currentMonth = month;
    final key = _monthKey(month);
    if (_cachedEvents.containsKey(key)) {
      // ✅ 同步更新 events（這是你缺的）
      final allCached = _cachedEvents[key]!;
      final allEvents = <EventItem>[];

      for (var week in allCached.values) {
        for (var dayEvents in week.values) {
          allEvents.addAll(dayEvents);
        }
      }

      // 移除重複事件
      events = allEvents.toSet().toList();

      if (notify) {
        notifyListeners(); // 更新畫面
      }
    } else {
      await loadCalendarEvents(notify: notify);
    }
  }

  // 查詢特定日期的事件
  List<EventItem> getEventsOfDay({required DateTime date}) {
    final key = _monthKey(date);
    Map<int, Map<int, List<EventItem>>>? weeks = _cachedEvents[key];

    if (weeks == null) {
      // 嘗試查前一月或後一月
      final DateTime prev = DateTime(date.year, date.month - 1);
      final DateTime next = DateTime(date.year, date.month + 1);
      if (_cachedEvents.containsKey(_monthKey(next))) {
        weeks = _cachedEvents[_monthKey(next)];
      } else if (_cachedEvents.containsKey(_monthKey(prev))) {
        weeks = _cachedEvents[_monthKey(prev)];
      }
    }

    if (weeks == null) return [];

    // 計算該日期在月曆中是第幾週第幾天
    final calendarWeeks = getCalendarDays(month: date);
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

  // 清除該事件相關月份的快取
  void updateCachedEvent({required EventItem event}) {
    final startDateS =
        event.startDate != null ? _monthKey(event.startDate!) : null;

    final endDateS = event.endDate != null ? _monthKey(event.endDate!) : null;

    // 移除快取
    if (startDateS != null && _cachedEvents.containsKey(startDateS)) {
      _cachedEvents.remove(startDateS);
    }
    if (endDateS != null && _cachedEvents.containsKey(endDateS)) {
      _cachedEvents.remove(endDateS);
    }
  }

  Future<void> checkAndGenerateNextEvents(
      {required AppLocalizations loc}) async {
    final service = getIt<ServiceStorage>();
    final DateTime today = DateTime.now();
    final Set<String> dirtyMonths = {};

    for (final event in events) {
      if (event.repeatOptions == RepeatRule.once) continue;

      final DateTime startDate = event.startDate!;

      // 如果今天已經是事件發生日，就生成下一個
      if (!DateTimeCompare.isSameDay(today, startDate)) continue;

      final DateTime nextStart = event.repeatOptions.getNextDate(startDate);
      final DateTime? nextEnd = event.endDate != null
          ? event.repeatOptions.getNextDate(event.endDate!)
          : null;

      final newEvent = event.copyWith(
        newId: Uuid().v4(),
        newStartDate: nextStart,
        newEndDate: nextEnd,
      );

      await service.saveEvent(
          event: newEvent, isNew: true, tableName: tableName, loc: loc);
      await NotificationEntryImpl.scheduleEventReminders(
          event: newEvent, tableName: tableName, loc: loc);

      // 更新舊事件的 repeatOption 為 'once'
      final updatedOldEvent = event.copyWith(
        newRepeatOptions: RepeatRule.once, // 更新 repeatOptions
      );

      // 儲存更新後的舊事件
      await service.saveEvent(
          event: updatedOldEvent, isNew: false, tableName: tableName, loc: loc);

      dirtyMonths.add(_monthKey(startDate));
      dirtyMonths.add(_monthKey(nextStart));
    }

    // 清除快取（僅影響有修改的月份）
    for (final key in dirtyMonths) {
      if (_cachedEvents.containsKey(key)) _cachedEvents.remove(key);
    }
    await loadCalendarEvents();
  }
}

class EventWithRow {
  final EventItem event;
  final int rowIndex;

  EventWithRow({required this.event, required this.rowIndex});
}
