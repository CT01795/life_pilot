import 'dart:async';
import 'dart:math';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:life_pilot/controllers/auth/controller_auth.dart';
import 'package:life_pilot/controllers/calendar/controller_notification.dart';
import 'package:life_pilot/controllers/calendar/controller_page_calendar_add.dart';
import 'package:life_pilot/models/event/model_event_calendar.dart';
import 'package:life_pilot/core/calendar/utils_calendar.dart';
import 'package:life_pilot/core/const.dart';
import 'package:life_pilot/core/date_time.dart';
import 'package:life_pilot/core/provider_locale.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/models/event/model_event_item.dart';
import 'package:life_pilot/services/event/service_event.dart';
import 'package:life_pilot/services/service_notification/notification_overlay.dart';
import 'package:life_pilot/services/service_permission.dart';
import 'package:uuid/uuid.dart';

class ControllerCalendar extends ChangeNotifier {
  ModelEventCalendar modelEventCalendar;
  ServiceEvent serviceEvent;
  ControllerNotification controllerNotification;
  ServicePermission servicePermission;
  ControllerAuth? auth;
  ProviderLocale localeProvider;
  String tableName;
  String toTableName;
  String closeText;
  Locale? _lastLocale;

  bool get isInitialized => modelEventCalendar.isInitialized;

  // 給 PageView 初始用的基準年月
  static final DateTime baseDate = DateTime(1911, 1);
  DateTime get currentMonth => modelEventCalendar.currentMonth;
  set currentMonth(DateTime value) {
    modelEventCalendar.currentMonth = value;
  }

  List<EventItem> get events => modelEventCalendar.events;
  int get pageIndex =>
      (currentMonth.year - baseDate.year) * 12 +
      (currentMonth.month - baseDate.month);

  int _reloadToken = 0;
  bool _isChangingMonth = false;

  ControllerCalendar(
      {required this.modelEventCalendar,
      required this.serviceEvent,
      required this.auth,
      required this.controllerNotification,
      required this.servicePermission,
      required this.localeProvider,
      required this.tableName,
      required this.toTableName,
      required this.closeText}) {
    _lastLocale = localeProvider.locale;

    localeProvider.addListener(() async {
      if (_lastLocale != localeProvider.locale) {
        _lastLocale = localeProvider.locale;
        clearAll();
        unawaited(reloadEvents(notify: true));
      }
    });
  }

  void updateLocalization(AppLocalizations loc) {
    closeText = loc.close;
    notifyListeners();
  }

  Future<void> init() async {
    if (modelEventCalendar.isInitialized) return;
    modelEventCalendar.isInitialized = true; // 提前鎖
    await goToMonth(month: currentMonth, notify: false);
    await checkAndGenerateNextEvents();
    notifyListeners();
  }

  // ------------------------
  // 核心事件載入與刷新
  // ------------------------
  Future<void> reloadEvents({bool notify = true, DateTime? month}) async {
    final targetMonth = month ?? currentMonth; // <-- 正確！不要用 DateTime.now
    final int myToken = ++_reloadToken; // 每次呼叫都生成新的 token
    List<EventItem> result = await modelEventCalendar.loadEventsFromService(
      serviceEvent: serviceEvent,
      month: targetMonth,
      auth: auth,
      localeProvider: localeProvider,
      tableName: tableName,
    );

    // ❗只允許最新請求寫入 model
    if (_reloadToken != myToken) {
      return;
    }
    if (result.isEmpty) {
      result = [];
    }
    modelEventCalendar.cacheMonthEvents(targetMonth, result);
    modelEventCalendar.setEvents(result);
    if (notify) {
      notifyListeners();
    }
  }

  // 載入月曆事件（含服務端與假日）
  Future<void> loadCalendarEvents(
      {required DateTime month, bool notify = true}) async {
    await reloadEvents(notify: notify, month: month);
  }

  // 跳轉月並同步資料（若有快取則不重新拉）
  Future<void> goToMonth({required DateTime month, bool notify = true}) async {
    if (_isChangingMonth) return;
    _isChangingMonth = true;
    try {
      final targetMonth = DateUtils.dateOnly(month);
      final key = targetMonth.toMonthKey();
      currentMonth = targetMonth;
      if (modelEventCalendar.cachedEvents.containsKey(key)) {
        // ✅ 同步更新 events
        modelEventCalendar.setMonthFromCache(key);
        if (notify) notifyListeners();
      } else {
        await reloadEvents(month: targetMonth, notify: notify);
      }
    } finally {
      _isChangingMonth = false;
    }
  }

  // 月份操作
  Future<void> goToOffsetMonth({required int offset}) async {
    final current = modelEventCalendar.currentMonth;
    await goToMonth(
      month: DateTime(current.year, current.month + offset),
    );
  }

  DateTime pageIndexToMonth({required int index}) {
    final year = baseDate.year + (index ~/ 12);
    final month = (index % 12) + baseDate.month;
    return DateTime(year, month);
  }

  // ------------------------
  // 重複事件生成
  // ------------------------
  Future<void> checkAndGenerateNextEvents() async {
    final DateTime today = DateTime.now();
    final Set<String> dirtyMonths = {};

    final eventsToGenerate = events.where((e) {
      return e.repeatOptions != RepeatRule.once &&
          DateTimeCompare.isSameDay(today, e.startDate!);
    }).toList();

    final futures = <Future>[];

    for (final event in eventsToGenerate) {
      final DateTime nextStart =
          event.repeatOptions.getNextDate(event.startDate!);
      final DateTime? nextEnd = event.endDate != null
          ? event.repeatOptions.getNextDate(event.endDate!)
          : null;

      final newEvent = event.copyWith(
        newId: Uuid().v4(),
        newStartDate: nextStart,
        newEndDate: nextEnd,
      );

      // 儲存新事件 & 安排提醒
      futures.add(serviceEvent.saveEvent(
          currentAccount: auth?.currentAccount ?? constEmpty,
          event: newEvent,
          isNew: true,
          tableName: tableName));
      futures
          .add(controllerNotification.scheduleEventReminders(event: newEvent));

      // 更新舊事件的 repeatOption 為 'once'
      futures.add(serviceEvent.saveEvent(
        currentAccount: auth?.currentAccount ?? constEmpty,
        event: event.copyWith(newRepeatOptions: RepeatRule.once),
        isNew: false,
        tableName: tableName,
      ));

      dirtyMonths
        ..add(event.startDate!.toMonthKey())
        ..add(nextStart.toMonthKey());
    }

    await Future.wait(futures);

    clearAll();
    await goToMonth(month: modelEventCalendar.currentMonth, notify: true);
  }

  // ------------------------
  // 由 View 主動呼叫顯示通知
  // ------------------------
  Future<void> showTodayNotifications() async {
    if (tableName != TableNames.calendarEvents) {
      return;
    }
    //行事曆的事件就通知
    final todayEvents = await controllerNotification.showTodayEvents(
      events: modelEventCalendar.events,
      closeText: closeText,
    );

    if (todayEvents.isEmpty) return;

    if (kIsWeb) {
      final showEvent = todayEvents[0];
      Timer(
        const Duration(seconds: 1),
        () => showWebOverlay(
          title: showEvent.title,
          body: showEvent.body,
          tooltip: showEvent.message ?? constEmpty,
        ),
      );
    } else {
      // 非阻塞顯示多個事件
      for (final event in todayEvents) {
        controllerNotification.service.plugin?.show(
          //拿掉await
          event.id ?? Random().nextInt(1000) + 1,
          event.title,
          event.body,
          event.details,
          payload: event.payload,
        );
      }
    }
  }

  // ------------------------
  // 日曆查詢
  // ------------------------
  List<List<DateTime>> getWeeks({required DateTime month}) {
    return modelEventCalendar.getWeeks(month);
  }

  // 拿到該月每週對應的事件層級（含排版 rowIndex）
  Map<int, List<EventWithRow>> getWeekEventRows({required DateTime month}) {
    final calendarWeeks = modelEventCalendar.getWeeks(month);
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

  // 工具方法：檢查兩個事件是否跨日重疊
  bool isOverlapping({required EventItem a, required EventItem b}) {
    final aStart = DateUtils.dateOnly(a.startDate!);
    final aEnd = DateUtils.dateOnly(a.endDate ?? a.startDate!);
    final bStart = DateUtils.dateOnly(b.startDate!);
    final bEnd = DateUtils.dateOnly(b.endDate ?? b.startDate!);

    return !(aEnd.isBefore(bStart) || aStart.isAfter(bEnd));
  }

  // ------------------------
  // 事件操作
  // ------------------------
  Future<void> addEvent(EventItem newEvent,
      {bool stayOnCurrentMonth = true}) async {
    modelEventCalendar.updateCachedEvent(event: newEvent);
    if (!stayOnCurrentMonth) {
      await goToMonth(month: DateUtils.monthOnly(newEvent.startDate!));
    }
    await goToMonth(
        month: DateUtils.monthOnly(modelEventCalendar.currentMonth));
  }

  List<EventItem> getEventsOfDay(DateTime date) {
    return modelEventCalendar.getEventsOfDay(date);
  }

  // 移動到上一個月份
  Future<void> previousMonth() async => await goToOffsetMonth(offset: -1);

  // 移動到下一個月份
  Future<void> nextMonth() async => await goToOffsetMonth(offset: 1);

  // 移動到今天
  Future<void> goToToday() async =>
      await goToMonth(month: DateUtils.dateOnly(DateTime.now()));

  // 點擊某個日期
  Future<void> tapDate(DateTime date) async {
    final dateOnly = DateUtils.dateOnly(date);
    // 處理跨月
    if (date.month != currentMonth.month || date.year != currentMonth.year) {
      await goToMonth(month: dateOnly);
    }
  }

  void clearAll() => modelEventCalendar.clearAll();

  // ---------------------------------------------------------------------------
  // 📦 CRUD 操作
  // ---------------------------------------------------------------------------
  Future<void> saveEvent({
    EventItem? oldEvent,
    required EventItem newEvent,
    bool isNew = true,
  }) async {
    await serviceEvent.saveEvent(
        currentAccount: auth!.currentAccount ?? constEmpty,
        event: newEvent,
        isNew: isNew,
        tableName: tableName);
  }

  // ✅ 刪除事件，並更新列表與通知 UI
  Future<void> deleteEvent(EventItem event) async {
    await Future.wait([
      controllerNotification.cancelEventReminders(
          eventId: event.id, reminderOptions: event.reminderOptions), // 取消通知
      serviceEvent.deleteEvent(
          currentAccount: auth!.currentAccount ?? constEmpty,
          event: event,
          tableName: tableName)
    ]);

    // 移除事件並更新快取
    modelEventCalendar
      ..removeEvent(event)
      ..markRemoved(event.id);
    notifyListeners();
  }

  // ✅ 建立單筆事件控制器
  ControllerPageCalendarAdd createAddController({
    EventItem? existingEvent,
    DateTime? initialDate,
  }) {
    return ControllerPageCalendarAdd(
      auth: auth!,
      serviceEvent: serviceEvent,
      tableName: tableName,
      existingEvent: existingEvent,
      initialDate: initialDate,
    );
  }

  Future<void> onEditEvent({
    required EventItem event,
    required EventItem updatedEvent,
  }) async {
    if (updatedEvent.startDate?.year != event.startDate!.year ||
        updatedEvent.startDate?.month != event.startDate!.month) {
      await loadCalendarEvents(month: updatedEvent.startDate!, notify: false);
    }
    await loadCalendarEvents(month: event.startDate!, notify: true);
  }

  Future<void> handleEventCheckboxTransfer(
    bool isChecked,
    bool isAlreadyAdded,
    EventItem event,
    String toTableName,
    EventItem? targetEvent,
  ) async {
    if (targetEvent != null && toTableName == TableNames.calendarEvents) {
      await refreshNotification(
        newEvent: event,
      );
      await loadCalendarEvents(month: event.startDate!, notify: false);
      goToMonth(month: DateTime.now(), notify: false);
    }
  }

  // ---------------------------------------------------------------------------
  // 🔔 通知管理
  // ---------------------------------------------------------------------------
  Future<void> refreshNotification({
    EventItem? oldEvent,
    required EventItem newEvent,
  }) async {
    if (tableName != TableNames.calendarEvents) return;
    if (oldEvent != null) {
      await controllerNotification.cancelEventReminders(
          eventId: oldEvent.id, reminderOptions: oldEvent.reminderOptions);
    }
    await servicePermission.checkExactAlarmPermission();
    await controllerNotification.scheduleEventReminders(event: newEvent);
  }

  Future<bool> updateAlarmSettings({
    required EventItem oldEvent,
    required EventItem newEvent,
  }) async {
    // Show dialog 交由 View 呼叫，這裡只處理邏輯
    // 例如取消舊通知、重新安排通知
    await refreshNotification(
        oldEvent: oldEvent,
        newEvent: newEvent);
    notifyListeners();
    return true;
  }

  Future<void> saveEventWithNotification({
    EventItem? oldEvent,
    required EventItem newEvent,
    bool isNew = true,
  }) async {
    if (isNew) {
      await servicePermission.checkExactAlarmPermission();
      await controllerNotification.scheduleEventReminders(event: newEvent);
    } else if (oldEvent != null) {
      await refreshNotification(oldEvent: oldEvent, newEvent: newEvent);
    }
  }
}
