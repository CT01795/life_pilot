import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:life_pilot/auth/controller_auth.dart';
import 'package:life_pilot/calendar/controller_notification.dart';
import 'package:life_pilot/calendar/controller_page_calendar_add.dart';
import 'package:life_pilot/calendar/model_calendar.dart';
import 'package:life_pilot/event/service_event_transfer.dart';
import 'package:life_pilot/utils/app_navigator.dart' as app_navigator;
import 'package:life_pilot/utils/const.dart';
import 'package:life_pilot/utils/date_time.dart';
import 'package:life_pilot/utils/enum.dart';
import 'package:life_pilot/utils/extension.dart';
import 'package:life_pilot/utils/logger.dart';
import 'package:life_pilot/utils/model_event_weather.dart';
import 'package:life_pilot/utils/provider_locale.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/event/model_event_item.dart';
import 'package:life_pilot/event/service_event.dart';
import 'package:life_pilot/utils/service/service_notification/notification_overlay.dart';
import 'package:life_pilot/utils/service/service_permission.dart';
import 'package:life_pilot/utils/service/service_weather.dart';
import 'package:uuid/uuid.dart';
import 'package:url_launcher/url_launcher.dart';

class ControllerCalendar extends ChangeNotifier {
  late String _googleApiKey;
  late ModelCalendar _modelCalendar;
  late ServiceEvent _serviceEvent;
  late ControllerNotification _controllerNotification;
  late ServiceWeather _serviceWeather;
  late ServicePermission _servicePermission;
  ControllerAuth? auth;
  late ProviderLocale _localeProvider;
  late String _tableName;
  late String _toTableName;
  String closeText;
  Locale? _lastLocale;

  // ------------------------
  // 狀態
  // ------------------------
  int _reloadToken = 0;
  bool _isChangingMonth = false;

  late ServiceEventTransfer _serviceEventTransfer;

  // ------------------------
  // Getter / Setter
  // ------------------------
  bool get isInitialized => _modelCalendar.isInitialized;

  bool isEventSelected(String eventId) {
    return _modelCalendar.selectedEventIds.contains(eventId);
  }

  // 給 PageView 初始用的基準年月
  DateTime get currentMonth => _modelCalendar.currentMonth;
  set currentMonth(DateTime value) {
    _modelCalendar.currentMonth = value;
  }

  List<EventItem> get events => _modelCalendar.events;

  static final DateTime baseDate = DateTime(1911, 1);
  int get pageIndex =>
      (currentMonth.year - baseDate.year) * 12 +
      (currentMonth.month - baseDate.month);

  // ------------------------
  // 建構子
  // ------------------------
  ControllerCalendar(
      {required ModelCalendar modelCalendar,
      required ServiceEvent serviceEvent,
      required this.auth,
      required ControllerNotification controllerNotification,
      required ServiceWeather serviceWeather,
      required ServicePermission servicePermission,
      required ProviderLocale localeProvider,
      required String tableName,
      required String toTableName,
      required this.closeText}) {
    _modelCalendar = modelCalendar;
    _serviceEvent = serviceEvent;
    _controllerNotification = controllerNotification;
    _serviceWeather = serviceWeather;
    _servicePermission = servicePermission;
    _localeProvider = localeProvider;
    _lastLocale = localeProvider.locale;
    _tableName = tableName;
    _toTableName = toTableName;

    localeProvider.addListener(() async {
      if (_lastLocale != localeProvider.locale) {
        _lastLocale = localeProvider.locale;
        clearAll();
        unawaited(reloadEvents(notify: true));
      }
    });

    _serviceEventTransfer = ServiceEventTransfer(
      currentAccount: auth?.currentAccount ?? '',
      serviceEvent: serviceEvent,
    );
  }
  void updateLocalization(AppLocalizations loc) {
    closeText = loc.close;
    notifyListeners();
  }

  Future<void> init() async {
    _googleApiKey = await _serviceEvent.getKey(
      keyName: "GOOGLE_API_KEY",
    );
    _modelCalendar.isInitialized = true; // 提前鎖
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
    List<EventItem> result = await _modelCalendar.loadEventsFromService(
      serviceEvent: _serviceEvent,
      month: targetMonth,
      auth: auth,
      localeProvider: _localeProvider,
      tableName: _tableName,
      googleApiKey: _googleApiKey,
    );

    // ✅ STOP: UI card 不再觸發 weather
    _warmUpWeather(result);

    // ❗只允許最新請求寫入 model
    if (_reloadToken != myToken) {
      return;
    }
    if (result.isEmpty) {
      result = [];
    }
    _modelCalendar.cacheMonthEvents(targetMonth, result);
    _modelCalendar.setEvents(result);
    if (notify) {
      notifyListeners();
    }
  }

  Future<void> _warmUpWeather(List<EventItem> events) async {
    for (final e in events) {
      final vm = buildViewModel(
        event: e,
        loc: AppLocalizations.of(app_navigator.navigatorKey.currentContext!)!,
      );

      await _serviceWeather.preloadWeather([vm]);

      // 👉 每秒一個
      await Future.delayed(const Duration(seconds: 1));
    }
  }

  EventViewModel buildViewModel({
    required EventItem event,
    required AppLocalizations loc,
  }) {
    EventViewModel tmp = EventViewModel.buildEventViewModel(
      event: event,
      parentLocation: '',
      canDelete: canDelete(
        account: event.account ?? '',
      ),
      showSubEvents: true,
      loc: loc,
      tableName: _tableName,
    );

    return tmp;
  }

  // 載入月曆事件（含服務端與假日）
  Future<void> loadCalendarEvents(
      {required DateTime month, bool notify = true}) async {
    await reloadEvents(notify: notify, month: month);
  }

  // ------------------------
  // 月份操作
  // ------------------------
  // 跳轉月並同步資料（若有快取則不重新拉）
  Future<void> goToMonth({required DateTime month, bool notify = true}) async {
    if (_isChangingMonth) return;
    _isChangingMonth = true;
    try {
      final targetMonth = DateTimeFormatter.dateOnly(month);
      final key = targetMonth.toMonthKey();
      currentMonth = targetMonth;
      if (_modelCalendar.cachedEvents.containsKey(key)) {
        // ✅ 同步更新 events
        _modelCalendar.setMonthFromCache(key);
        if (notify) notifyListeners();
      } else {
        await reloadEvents(month: targetMonth, notify: notify);
      }
      unawaited(reloadEvents(
        month: DateTime(targetMonth.year, targetMonth.month + 1),
        notify: false,
      ));
      unawaited(reloadEvents(
        month: DateTime(targetMonth.year, targetMonth.month - 1),
        notify: false,
      ));
    } finally {
      _isChangingMonth = false;
    }
  }

  Future<void> goToOffsetMonth({required int offset}) async {
    final current = _modelCalendar.currentMonth;
    await goToMonth(
      month: DateTime(current.year, current.month + offset),
    );
  }

  // 移動到今天
  Future<void> goToToday() async =>
      await goToMonth(month: DateTimeFormatter.dateOnly(DateTime.now()));

  // 點擊某個日期
  Future<void> tapDate(DateTime date) async {
    final dateOnly = DateTimeFormatter.dateOnly(date);
    // 處理跨月
    if (date.month != currentMonth.month || date.year != currentMonth.year) {
      await goToMonth(month: dateOnly);
    }
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
      return e.repeatOptions != CalendarRepeatRule.once &&
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
      futures.add(_serviceEvent.saveEvent(
          currentAccount: auth?.currentAccount ?? '',
          event: newEvent,
          isNew: true,
          tableName: _tableName));
      futures
          .add(_controllerNotification.scheduleEventReminders(event: newEvent));

      // 更新舊事件的 repeatOption 為 'once'
      futures.add(_serviceEvent.saveEvent(
        currentAccount: auth?.currentAccount ?? '',
        event: event.copyWith(newRepeatOptions: CalendarRepeatRule.once),
        isNew: false,
        tableName: _tableName,
      ));

      dirtyMonths
        ..add(event.startDate!.toMonthKey())
        ..add(nextStart.toMonthKey());
    }

    await Future.wait(futures);

    clearAll();
    await goToMonth(month: _modelCalendar.currentMonth, notify: true);
  }

  // ------------------------
  // 事件操作
  // ------------------------
  Future<void> addEvent(EventItem newEvent,
      {bool stayOnCurrentMonth = true}) async {
    _modelCalendar.updateCachedEvent(event: newEvent);
    if (!stayOnCurrentMonth) {
      await goToMonth(month: DateTimeFormatter.monthOnly(newEvent.startDate!));
    }
    await goToMonth(
        month: DateTimeFormatter.monthOnly(_modelCalendar.currentMonth));
  }

  Future<void> onEditEvent({
    required EventItem event,
    required EventItem? updatedEvent,
  }) async {
    if (updatedEvent == null) return;
    // 移除快取
    _modelCalendar.updateCachedEvent(event: event);
    _modelCalendar.updateCachedEvent(event: updatedEvent);
    final newMonth = DateTimeFormatter.monthOnly(updatedEvent.startDate!);
    final oldMonth = DateTimeFormatter.monthOnly(event.startDate!);
    final now = DateTimeFormatter.monthOnly(currentMonth);
    await loadCalendarEvents(month: now, notify: true);
    if (newMonth != oldMonth) {
      loadCalendarEvents(month: newMonth, notify: newMonth == now);
      loadCalendarEvents(month: oldMonth, notify: oldMonth == now);
    }
  }

  // ✅ 刪除事件，並更新列表與通知 UI
  Future<void> deleteEvent(EventItem event) async {
    await Future.wait([
      _controllerNotification.cancelEventReminders(
          eventId: event.id, reminderOptions: event.reminderOptions), // 取消通知
      _serviceEvent.deleteEvent(
          currentAccount: auth!.currentAccount ?? '',
          event: event,
          tableName: _tableName)
    ]);

    // 移除事件並更新快取
    _modelCalendar
      ..removeEvent(event)
      ..markRemoved(event.id);
    notifyListeners();
  }

  Future<void> saveEventWithNotification({
    EventItem? oldEvent,
    required EventItem newEvent,
    bool isNew = true,
  }) async {
    await _serviceEvent.saveEvent(
        currentAccount: auth!.currentAccount ?? '',
        event: newEvent,
        isNew: isNew,
        tableName: _tableName);
    if (isNew) {
      await _servicePermission.checkExactAlarmPermission();
      await _controllerNotification.scheduleEventReminders(event: newEvent);
    } else if (oldEvent != null) {
      await refreshNotification(oldEvent: oldEvent, newEvent: newEvent);
    }
  }

  Future<void> saveSettings({
    required EventItem event,
    required CalendarRepeatRule repeat,
    required List<CalendarReminderOption> reminders,
  }) async {
    // 更新事件資料
    final updatedEvent = event.copyWith(
      newReminderOptions: reminders,
      newRepeatOptions: repeat,
    );

    await saveEventWithNotification(
      oldEvent: event,
      newEvent: updatedEvent,
      isNew: false,
    );

    // 重新載入事件
    await loadCalendarEvents(month: updatedEvent.startDate!);

    // 若為重複事件，自動生成下一次
    if (updatedEvent.repeatOptions.key.startsWith('every')) {
      await checkAndGenerateNextEvents();
    }
  }

  // ✅ 建立單筆事件控制器
  ControllerPageCalendarAdd createAddController({
    EventItem? existingEvent,
    DateTime? initialDate,
  }) {
    return ControllerPageCalendarAdd(
      auth: auth!,
      tableName: _tableName,
      existingEvent: existingEvent,
      initialDate: initialDate,
    );
  }

  List<EventItem> getEventsOfDay(DateTime date) {
    return _modelCalendar.getEventsOfDay(date);
  }

  // ---------------------------------------------------------------------------
  // 🔔 通知管理
  // ---------------------------------------------------------------------------
  Future<void> refreshNotification({
    EventItem? oldEvent,
    required EventItem newEvent,
  }) async {
    if (_tableName != TableNames.calendarEvents) return;
    if (oldEvent != null) {
      await _controllerNotification.cancelEventReminders(
          eventId: oldEvent.id, reminderOptions: oldEvent.reminderOptions);
    }
    await _servicePermission.checkExactAlarmPermission();
    await _controllerNotification.scheduleEventReminders(event: newEvent);
  }

  Future<void> showTodayNotifications() async {
    if (_tableName != TableNames.calendarEvents) {
      return;
    }
    //行事曆的事件就通知
    final todayEvents = await _controllerNotification.showTodayEvents(
      events: _modelCalendar.events,
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
          tooltip: showEvent.message ?? '',
        ),
      );
    } else {
      // 非阻塞顯示多個事件
      for (final event in todayEvents) {
        _controllerNotification.service.plugin?.show(
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
    return _modelCalendar.getWeeks(month);
  }

  // 拿到該月每週對應的事件層級（含排版 rowIndex）
  Map<int, List<EventWithRow>> getWeekEventRows({required DateTime month}) {
    final calendarWeeks = _modelCalendar.getWeeks(month);
    final weekEventRows = <int, List<EventWithRow>>{};

    for (int weekIndex = 0; weekIndex < calendarWeeks.length; weekIndex++) {
      final week = calendarWeeks[weekIndex];
      final weekStart = week.first;
      final weekEnd = week.last;

      final eventsThisWeek = events.where((event) {
        final start = DateTimeFormatter.dateOnly(event.startDate!);
        final end =
            DateTimeFormatter.dateOnly(event.endDate ?? event.startDate!);
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
    final aStart = DateTimeFormatter.dateOnly(a.startDate!);
    final aEnd = DateTimeFormatter.dateOnly(a.endDate ?? a.startDate!);
    final bStart = DateTimeFormatter.dateOnly(b.startDate!);
    final bEnd = DateTimeFormatter.dateOnly(b.endDate ?? b.startDate!);

    return !(aEnd.isBefore(bStart) || aStart.isAfter(bEnd));
  }

  // ------------------------
  // 搜尋 / 篩選 / 選擇
  // ------------------------
  void toggleEventSelection(String eventId, bool isSelected) {
    _modelCalendar.toggleEventSelection(eventId, isSelected);
    notifyListeners();
  }

  // ------------------------
  // 跨 Table 操作
  // ------------------------
  Future<EventItem?> handleEventCheckboxTransfer(
    bool isChecked,
    bool isAlreadyAdded,
    EventItem event,
  ) async {
    final targetEvent = await _serviceEventTransfer.toggleEventTransfer(
      isChecked: isChecked,
      isAlreadyAdded: isAlreadyAdded,
      event: event,
      fromTableName: _tableName,
      toTableName: _toTableName,
    );
    _modelCalendar.toggleEventSelection(event.id, targetEvent != null);
    return targetEvent;
  }

  Future<bool> handleEventCheckboxIsAlreadyAdd(
    EventItem event,
    bool isChecked,
  ) async {
    // 先更新 UI
    toggleEventSelection(event.id, isChecked);

    return await _serviceEventTransfer.toggleEventTransferIsAlreadyAdd(
        event: event, toTableName: _toTableName, isChecked: isChecked);
  }

  String buildTransferMessage({
    required bool isAlreadyAdded,
    required EventItem event,
    required AppLocalizations loc,
  }) {
    if (isAlreadyAdded) {
      return loc.memoryAddError;
    } else {
      return '${loc.memoryAdd}「${event.name}」？';
    }
  }

  Future<void> handleCrossMonthTap({
    required DateTime tappedDate,
  }) async {
    if (tappedDate.month != currentMonth.month ||
        tappedDate.year != currentMonth.year) {
      // 預載其他月份事件，但不改 displayedMonth
      await loadCalendarEvents(
          month: DateTime(tappedDate.year, tappedDate.month), notify: false);
      await goToMonth(month: currentMonth, notify: true);
    }
  }

  // ------------------------
  // 工具
  // ------------------------
  void clearAll() => _modelCalendar.clearAll();

  bool canDelete({
    required String account,
  }) {
    if (auth == null) {
      return false;
    }
    return auth!.currentAccount == account ||
        (auth!.currentAccount == AuthConstants.sysAdminEmail &&
            _tableName != TableNames.memoryTrace);
  }

  // 移動到上一個月份
  Future<void> previousMonth() async => await goToOffsetMonth(offset: -1);

  // 移動到下一個月份
  Future<void> nextMonth() async => await goToOffsetMonth(offset: 1);

  Future<Map<String, String>> updateAlarmSettings({
    required EventItem event,
    required CalendarRepeatRule repeat,
    required List<CalendarReminderOption> reminders,
    required AppLocalizations loc,
  }) async {
    try {
      await saveSettings(
        event: event,
        repeat: repeat,
        reminders: reminders,
      );

      if (reminders.isNotEmpty) {
        return {
          "msg":
              '${loc.setAlarm} ${reminders.map((r) => r.label(loc)).join(", ")}'
        };
      } else {
        return {"msg": loc.cancelAlarm};
      }
    } catch (e, st) {
      logger.e('❌ saveSettings error: $e', stackTrace: st);
      return {"error": '❌ error: ${e.toString()}'};
    }
  }

  // ------------------ controller event card ------------------

  // ------------------ Public ------------------
  List<EventWeather>? getForecast({required String locationDisplay}) {
    return _serviceWeather.getForecast(locationDisplay: locationDisplay);
  }

  // 取得天氣預報（緩存）
  Future<List<EventWeather>?> loadWeather(EventViewModel event) async {
    return await _serviceWeather.loadWeather(
      event: event,
      hasLocation: event.hasLocation,
      locationDisplay: event.locationDisplay,
      startDate: event.startDate,
      endDate: event.endDate,
      tableName: _tableName,
    );
  }

  // 開啟活動連結
  Future<void> onOpenLink(EventViewModel event) async {
    if (event.masterUrl == null || event.masterUrl!.isEmpty) return;
    await _launchUrl(
      Uri.parse(event.masterUrl!),
      event,
      column: 'page_views',
    );
  }

  // 開啟地圖導航
  Future<void> onOpenMap(EventViewModel event) async {
    if (event.locationDisplay.isEmpty) return;
    final query = Uri.encodeComponent(event.locationDisplay);

    // Google Maps 網頁導航 URL
    final googleMapsUrl =
        Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$query');
    await _launchUrl(
      googleMapsUrl,
      event,
      column: 'card_clicks',
    );
  }

  // ------------------ Private ------------------

  /// 統一處理 URL 開啟與事件計數
  Future<void> _launchUrl(Uri uri, EventViewModel event,
      {required String column}) async {
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      await _incrementCounter(event, column);
    } catch (e) {
      logger.e('Failed to launch URL for ${event.id}: $e');
    }
  }

  /// 統一事件計數
  Future<void> _incrementCounter(EventViewModel event, String column) async {
    try {
      await _serviceEvent.incrementEventCounter(
        eventId: event.id,
        eventName: event.name,
        column: column,
        account: auth!.currentAccount!,
      );
    } catch (e) {
      logger.e('Failed to increment counter for ${event.id} ($column): $e');
    }
  }
}