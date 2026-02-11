import 'package:flutter/material.dart' hide DateUtils;
import 'package:life_pilot/controllers/auth/controller_auth.dart';
import 'package:life_pilot/controllers/calendar/controller_calendar.dart';
import 'package:life_pilot/controllers/calendar/controller_notification.dart';
import 'package:life_pilot/models/event/model_event_calendar.dart';
import 'package:life_pilot/controllers/event/controller_page_event_add.dart';
import 'package:life_pilot/core/const.dart';
import 'package:life_pilot/core/date_time.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/models/event/model_event_base.dart';
import 'package:life_pilot/models/event/model_event_item.dart';
import 'package:life_pilot/services/event/service_event.dart';
import 'package:life_pilot/services/event/service_event_transfer.dart';
import 'package:life_pilot/services/service_permission.dart';

// ControllerEvent → 整體事件管理、查詢、刪除、UI通知
// EventController → 單筆事件顯示的欄位包裝（提供 View 用的 getter）
class ControllerEvent extends ChangeNotifier {
  final ControllerAuth auth;
  final ServiceEvent serviceEvent;
  final ServicePermission servicePermission;
  ControllerNotification controllerNotification;
  final ModelEventCalendar modelEventCalendar;
  final String tableName;
  final String? toTableName;
  late final ServiceEventTransfer serviceEventTransfer;
  final Future<void> Function()? onCalendarReload;

  ControllerEvent(
      {required this.auth,
      required this.serviceEvent,
      required this.servicePermission,
      required this.controllerNotification,
      required this.modelEventCalendar,
      required this.tableName,
      this.toTableName,
      this.onCalendarReload}) {
    serviceEventTransfer = ServiceEventTransfer(
      currentAccount: auth.currentAccount ?? constEmpty,
      serviceEvent: serviceEvent,
    );
  }

  // ---------------------------------------------------------------------------
  // 📦 CRUD 操作
  // ---------------------------------------------------------------------------
  Future<void> loadEvents() async {
    final list = await serviceEvent.getEvents(
      tableName: tableName,
      inputUser: auth.currentAccount,
    );
    modelEventCalendar.setEvents(list ?? []);
    notifyListeners();
  }

  Future<void> saveEventWithNotification({
    EventItem? oldEvent,
    required EventItem newEvent,
    bool isNew = true,
  }) async {
    await serviceEvent.saveEvent(
        currentAccount: auth.currentAccount ?? constEmpty,
        event: newEvent,
        isNew: isNew,
        tableName: tableName);
    if (tableName != TableNames.calendarEvents) return;
    if (isNew) {
      await servicePermission.checkExactAlarmPermission();
      await controllerNotification.scheduleEventReminders(event: newEvent);
    } else if (oldEvent != null) {
      await refreshNotification(oldEvent: oldEvent, newEvent: newEvent);
    }
  }

  // ✅ 刪除事件，並更新列表與通知 UI
  Future<void> deleteEvent(EventItem event) async {
    await Future.wait([
      controllerNotification.cancelEventReminders(
          eventId: event.id, reminderOptions: event.reminderOptions), // 取消通知
      serviceEvent.deleteEvent(
          currentAccount: auth.currentAccount ?? constEmpty,
          event: event,
          tableName: tableName)
    ]);

    // 移除事件並更新快取
    modelEventCalendar
      ..removeEvent(event)
      ..markRemoved(event.id);
    notifyListeners();
  }

  Future<void> approveEvent({required EventItem event}) async {
    event.isApproved = true;
    await serviceEvent.approvalEvent(event: event, tableName: tableName);
    await loadEvents();
  }

  bool canDelete({required String account}) {
    return auth.currentAccount == account ||
        (auth.currentAccount == AuthConstants.sysAdminEmail &&
            tableName != TableNames.memoryTrace);
  }

  Future<void> likeEvent(
      {required EventItem event, required String account}) async {
    event.isLike = event.isLike == true ? false : true;
    event.isDislike = event.isLike == true ? false : event.isDislike;
    await serviceEvent.updateLikeEvent(event: event, account: account);
    if (tableName == TableNames.recommendedEvents ||
        tableName == TableNames.calendarEvents ||
        tableName == TableNames.memoryTrace) {
      // 🔹 呼叫 function 更新資料庫
      await serviceEvent.incrementEventCounter(
          eventId: event.id,
          eventName: event.name, // 或者用 eventViewModel.name
          column: event.isLike == true ? 'like_counts' : 'card_clicks',
          account: auth.currentAccount ?? AuthConstants.guest);
    }
    await loadEvents();
  }

  Future<void> dislikeEvent(
      {required EventItem event, required String account}) async {
    event.isDislike = event.isDislike == true ? false : true;
    event.isLike = event.isDislike == true ? false : event.isLike;
    await serviceEvent.updateLikeEvent(event: event, account: account);
    if (tableName == TableNames.recommendedEvents ||
        tableName == TableNames.calendarEvents ||
        tableName == TableNames.memoryTrace) {
      // 🔹 呼叫 function 更新資料庫
      await serviceEvent.incrementEventCounter(
          eventId: event.id,
          eventName: event.name, // 或者用 eventViewModel.name
          column: event.isDislike == true ? 'dislike_counts' : 'card_clicks',
          account: auth.currentAccount ?? AuthConstants.guest);
    }
    await loadEvents();
  }

  // ✅ 建立單筆事件控制器
  ControllerPageEventAdd createAddController({
    EventItem? existingEvent,
    DateTime? initialDate,
  }) {
    return ControllerPageEventAdd(
      auth: auth,
      serviceEvent: serviceEvent,
      tableName: tableName,
      existingEvent: existingEvent,
      initialDate: initialDate,
    );
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
    await refreshNotification(oldEvent: oldEvent, newEvent: newEvent);
    notifyListeners();
    return true;
  }

  // ---------------------------------------------------------------------------
  // 🔁 事件編輯 / 同步 UI
  // ---------------------------------------------------------------------------
  Future<void> onEditEvent({
    required EventItem event,
    required EventItem? updatedEvent,
    ControllerCalendar? controllerCalendar,
  }) async {
    if (updatedEvent == null) return;
    // 移除快取
    modelEventCalendar.updateCachedEvent(event: event);
    if (tableName == TableNames.calendarEvents) {
      if (updatedEvent.startDate!.year != event.startDate!.year ||
          updatedEvent.startDate!.month != event.startDate!.month) {
        await controllerCalendar?.loadCalendarEvents(
            month: updatedEvent.startDate!, notify: false);
      }
      await controllerCalendar?.loadCalendarEvents(
          month: event.startDate!, notify: true);
    } else {
      await loadEvents(); // 自動刷新列表
    }
  }

  // ---------------------------------------------------------------------------
  // 🔄 資料轉移（跨 Table）
  // ---------------------------------------------------------------------------
  // ✅ Checkbox 點擊事件處理
  Future<bool> handleEventCheckboxIsAlreadyAdd(
    EventItem event,
    bool isChecked,
    String toTableName,
  ) async {
    // 先更新 UI
    toggleEventSelection(event.id, isChecked);

    return await serviceEventTransfer.toggleEventTransferIsAlreadyAdd(
        event: event, toTableName: toTableName, isChecked: isChecked);
  }

  Future<void> handleEventCheckboxTransfer(
    bool isChecked,
    bool isAlreadyAdded,
    EventItem event,
    ControllerCalendar controllerCalendar,
    String toTableName,
  ) async {
    final targetEvent = await serviceEventTransfer.toggleEventTransfer(
      isChecked: isChecked,
      isAlreadyAdded: isAlreadyAdded,
      event: event,
      fromTableName: tableName,
      toTableName: toTableName,
    );
    modelEventCalendar.toggleEventSelection(event.id, targetEvent != null);
    if (targetEvent != null && toTableName == TableNames.calendarEvents) {
      await refreshNotification(
        newEvent: event,
      );
      await controllerCalendar.loadCalendarEvents(
          month: event.startDate!, notify: false);
      controllerCalendar.goToMonth(month: DateTime.now(), notify: false);

      // 🔹 呼叫 function 更新資料庫
      await serviceEvent.incrementEventCounter(
          eventId: event.id,
          eventName: event.name, // 或者用 eventViewModel.name
          column: 'saves', //收藏到行事曆
          account: auth.currentAccount ?? AuthConstants.guest);
      await loadEvents();
    } else {
      notifyListeners();
    }
  }

  String buildTransferMessage({
    required bool isAlreadyAdded,
    required String fromTableName,
    required EventItem event,
    required AppLocalizations loc,
  }) {
    if (isAlreadyAdded) {
      return fromTableName == TableNames.calendarEvents
          ? loc.memoryAddError
          : loc.eventAddError;
    } else {
      return '${fromTableName == TableNames.calendarEvents ? loc.memoryAdd : loc.eventAdd}「${event.name}」？';
    }
  }

  // ---------------------------------------------------------------------------
  // 🔍 搜尋與篩選控制
  // ---------------------------------------------------------------------------
  void toggleEventSelection(String eventId, bool isSelected) {
    modelEventCalendar.toggleEventSelection(eventId, isSelected);
    notifyListeners();
  }

  void toggleSearchPanel(bool value) {
    modelEventCalendar.toggleSearchPanel(value);
    notifyListeners();
  }

  void updateKeywords(
    String? keywords,
  ) {
    modelEventCalendar.updateSearchKeywords(keywords);

    final controller = modelEventCalendar.searchController;
    final filter = modelEventCalendar.searchFilter;

    if (keywords == null || keywords.isEmpty) {
      filter.tags.clear();
      controller.clear();
      notifyListeners();
      return;
    }

    // 如果最後一個字元是空白 → 產生 tag
    final keywordList = keywords
        .split(RegExp(r'[,，\s]+'))
        .map((s) => s
            .trim()) // 只修剪每個 tag 前後空白 .split(RegExp(r'[,，\s]+')) // ← 逗號（英文/中文）或任意空白都分隔
        .where((s) => s.isNotEmpty)
        .toList();
    filter.tags.clear();
    if (keywordList.isNotEmpty) {
      filter.tags = keywordList;
    }
    notifyListeners();
    return;
  }

  void updateStartDate(
    DateTime? startDate,
  ) {
    modelEventCalendar.updateStartDate(startDate);
    notifyListeners();
  }

  void updateEndDate(
    DateTime? endDate,
  ) {
    modelEventCalendar.updateEndDate(endDate);
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // 🧩 UI 資料封裝
  // ---------------------------------------------------------------------------
  EventViewModel buildEventViewModel({
    required EventBase event,
    required String parentLocation,
    required bool canDelete,
    bool showSubEvents = true,
    required AppLocalizations loc,
  }) {
    final locationDisplay = (event.city.isNotEmpty || event.location.isNotEmpty)
        ? '${event.city}．${event.location}'
        : constEmpty;

    String isFree = event.isFree == null
        ? constEmpty
        : (event.isFree! ? loc.free : loc.pay);
    String isOutdoor = event.isOutdoor == null
        ? constEmpty
        : (event.isOutdoor! ? loc.outdoor : loc.indoor);
    String ageRange = event.ageMin == null
        ? constEmpty
        : "${event.ageMin}y~${event.ageMax == null ? constEmpty : "${event.ageMax}y"}";
    String priceRange = event.priceMin == null
        ? constEmpty
        : "\$${event.priceMin}~${event.priceMax == null ? constEmpty : "\$${event.priceMax}"}";
    // 處理 tags
    final tagsRawData = <String>[
      isFree,
      isOutdoor,
      ageRange,
      priceRange,
      event.type
    ].where((t) => t.isNotEmpty).toList();

    final tags = tagsRawData
        .expand((t) => t.split(RegExp(r'[\s,，]')))
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .take(3)
        .toList();

    return EventViewModel(
      id: event.id,
      name: event.name,
      showDate: tableName != TableNames.recommendedAttractions,
      startDate: event.startDate,
      endDate: event.endDate,
      dateRange: tableName != TableNames.recommendedAttractions
          ? '${DateTimeFormatter.formatEventDateTime(event, CalendarMisc.startToS)}'
              '${DateTimeFormatter.formatEventDateTime(event, CalendarMisc.endToE)}'
          : constEmpty,
      tags: tags,
      hasLocation:
          locationDisplay.isNotEmpty && locationDisplay != parentLocation,
      locationDisplay: locationDisplay,
      masterUrl: event.masterUrl,
      description: event.description,
      subEvents: showSubEvents
          ? event.subEvents
              .map((sub) => buildEventViewModel(
                  event: sub,
                  parentLocation: locationDisplay,
                  canDelete: canDelete,
                  showSubEvents: showSubEvents,
                  loc: loc))
              .toList()
          : const [],
      canDelete: canDelete,
      showSubEvents: showSubEvents,
      ageMin: event.ageMin,
      ageMax: event.ageMax,
      isFree: event.isFree,
      priceMin: event.priceMin,
      priceMax: event.priceMax,
      isOutdoor: event.isOutdoor,
      isLike: event.isLike,
      isDislike: event.isDislike,
      pageViews: event.pageViews,
      cardClicks: event.cardClicks,
      saves: event.saves,
      registrationClicks: event.registrationClicks,
      likeCounts: event.likeCounts,
      dislikeCounts: event.dislikeCounts,
    );
  }

  // 判斷日期是否要顯示
  bool showDate() {
    return tableName != TableNames.recommendedAttractions;
  }
}

// EventController → 單筆事件顯示的欄位包裝（提供 View 用的 getter）
class EventViewModel {
  final String id;
  final String name;
  final bool showDate;
  final String dateRange;
  List<String> tags;
  final bool hasLocation;
  final String locationDisplay;
  final String? masterUrl;
  final String description;
  final List<EventViewModel> subEvents;
  final bool canDelete;
  final bool showSubEvents;
  final DateTime? startDate;
  final DateTime? endDate;
  final num? ageMin;
  final num? ageMax;
  final bool? isFree;
  final num? priceMin;
  final num? priceMax;
  final bool? isOutdoor;
  final bool? isLike;
  final bool? isDislike;
  final int? pageViews;
  final int? cardClicks;
  final int? saves;
  final int? registrationClicks;
  final int? likeCounts;
  final int? dislikeCounts;

  EventViewModel({
    required this.id,
    required this.name,
    required this.showDate,
    required this.startDate,
    required this.endDate,
    required this.dateRange,
    required this.tags,
    required this.hasLocation,
    required this.locationDisplay,
    this.masterUrl,
    this.description = constEmpty,
    this.subEvents = const [],
    this.canDelete = false,
    this.showSubEvents = true,
    this.ageMin,
    this.ageMax,
    this.isFree,
    this.priceMin,
    this.priceMax,
    this.isOutdoor,
    this.isLike,
    this.isDislike,
    this.pageViews,
    this.cardClicks,
    this.saves,
    this.registrationClicks,
    this.likeCounts,
    this.dislikeCounts,
  });
}
