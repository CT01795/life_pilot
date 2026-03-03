import 'package:flutter/material.dart';
import 'package:life_pilot/auth/controller_auth.dart';
import 'package:life_pilot/event/model_event_calendar.dart';
import 'package:life_pilot/event/controller_page_event_add.dart';
import 'package:life_pilot/event/service_event_public.dart';
import 'package:life_pilot/utils/const.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/event/model_event_item.dart';
import 'package:life_pilot/event/service_event.dart';
import 'package:life_pilot/event/service_event_transfer_ok.dart';
import 'package:life_pilot/utils/date_time.dart';
import 'package:life_pilot/utils/logger.dart';
import 'package:life_pilot/utils/model_event_weather.dart';
import 'dart:async';
import 'package:life_pilot/utils/service/service_weather.dart';
import 'package:url_launcher/url_launcher.dart';

class ControllerEvent extends ChangeNotifier {
  final ControllerAuth auth;
  final ServiceEvent _serviceEvent;
  final ServiceWeather _serviceWeather;
  final ModelEventCalendar modelEventCalendar;
  final String tableName;
  final String? toTableName;
  late final ServiceEventTransfer serviceEventTransfer;
  final Future<void> Function()? onCalendarReload;

  ControllerEvent(
      {required this.auth,
      required ServiceEvent serviceEvent,
      required ServiceWeather serviceWeather,
      required this.modelEventCalendar,
      required this.tableName,
      this.toTableName,
      this.onCalendarReload}):
      _serviceEvent = serviceEvent,
      _serviceWeather = serviceWeather,
      serviceEventTransfer = ServiceEventTransfer(
      currentAccount: auth.currentAccount ?? '',
      serviceEvent: serviceEvent);
  
  ServiceEvent get serviceEvent => _serviceEvent;
  ServiceWeather get serviceWeather => _serviceWeather;

  // ---------------------------------------------------------------------------
  // 📦 CRUD 操作
  // ---------------------------------------------------------------------------
  Future<void> loadEvents() async {
    final list = await _serviceEvent.getEvents(
      tableName: tableName,
      inputUser: auth.currentAccount,
    );
    modelEventCalendar.setEvents(list ?? []);
    notifyListeners();
  }

  Future<void> saveEvent({
    EventItem? oldEvent,
    required EventItem newEvent,
    bool isNew = true,
  }) async {
    await _serviceEvent.saveEvent(
        currentAccount: auth.currentAccount ?? '',
        event: newEvent,
        isNew: isNew,
        tableName: tableName);
  }

  // ✅ 刪除事件，並更新列表與通知 UI
  Future<void> deleteEvent(EventItem event) async {
    await Future.wait([
      _serviceEvent.deleteEvent(
          currentAccount: auth.currentAccount ?? '',
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
    await _serviceEvent.approvalEvent(event: event, tableName: tableName);
    await loadEvents();
  }

  bool canDelete({required String account}) {
    return auth.currentAccount == account ||
        (auth.currentAccount == AuthConstants.sysAdminEmail &&
            tableName != TableNames.memoryTrace);
  }

  Future<void> likeEvent(EventItem event) async {
    event.isLike = event.isLike == true ? false : true;
    event.isDislike = event.isLike == true ? false : event.isDislike;
    await _serviceEvent.updateLikeEvent(
        event: event, account: auth.currentAccount!);
    if (tableName == TableNames.recommendedEvents ||
        tableName == TableNames.calendarEvents ||
        tableName == TableNames.memoryTrace) {
      // 🔹 呼叫 function 更新資料庫
      await _serviceEvent.incrementEventCounter(
          eventId: event.id,
          eventName: event.name, // 或者用 eventViewModel.name
          column: event.isLike == true ? 'like_counts' : 'card_clicks',
          account: auth.currentAccount ?? AuthConstants.guest);
    }
    await loadEvents();
  }

  Future<void> dislikeEvent(EventItem event) async {
    event.isDislike = event.isDislike == true ? false : true;
    event.isLike = event.isDislike == true ? false : event.isLike;
    await _serviceEvent.updateLikeEvent(
        event: event, account: auth.currentAccount!);
    if (tableName == TableNames.recommendedEvents ||
        tableName == TableNames.calendarEvents ||
        tableName == TableNames.memoryTrace) {
      // 🔹 呼叫 function 更新資料庫
      await _serviceEvent.incrementEventCounter(
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
      tableName: tableName,
      existingEvent: existingEvent,
      initialDate: initialDate,
    );
  }

  // ---------------------------------------------------------------------------
  // 🔁 事件編輯 / 同步 UI
  // ---------------------------------------------------------------------------
  Future<void> onEditEvent({
    required EventItem event,
    required EventItem? updatedEvent,
  }) async {
    if (updatedEvent == null) return;
    if (tableName != TableNames.calendarEvents) {
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

  Future<EventItem?> handleEventCheckboxTransfer(
    bool isChecked,
    bool isAlreadyAdded,
    EventItem event,
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
      // 🔹 呼叫 function 更新資料庫
      await _serviceEvent.incrementEventCounter(
          eventId: event.id,
          eventName: event.name, // 或者用 eventViewModel.name
          column: 'saves', //收藏到行事曆
          account: auth.currentAccount ?? AuthConstants.guest);
      await loadEvents();
    } else {
      notifyListeners();
    }
    return targetEvent;
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

  // 判斷日期是否要顯示
  bool showDate() {
    return tableName != TableNames.recommendedAttractions;
  }

  EventViewModel buildViewModel({
    required EventItem event,
    required String tableName,
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
      tableName: tableName,
    );

    return tmp;
  }

  Future<void> refreshEvents() async {
    await ServiceEventPublic().fetchAndSaveAllEvents();

    loadEvents(); // notifyListeners()
  }

  // ------------------ controller event card ------------------
  bool disposed = false;

  final Set<String> _loadingIds = {};
  final Map<String, List<EventWeather>> _forecastCache = {};

  // ------------------ Public ------------------
  List<EventWeather>? getForecast(String eventId) {
    return _forecastCache[eventId];
  }

  Future<void> loadWeather(EventViewModel event, String tableName) async {
    if (!event.hasLocation) return;
    if (_forecastCache.containsKey(event.id)) return;
    if (_loadingIds.contains(event.id)) return;
    final today = DateTimeFormatter.dateOnly(DateTime.now());
    if (tableName == TableNames.recommendedAttractions) {
    } else if (event.locationDisplay.isEmpty ||
        (event.startDate != null &&
            ((today.add(Duration(days: 7))).isBefore(event.startDate!) ||
                today.isAfter(event.startDate!)))) {
      return;
    }

    _loadingIds.add(event.id);

    try {
      final data = await _serviceWeather.getWeather(
          locationDisplay: event.locationDisplay, startDate: event.startDate);

      _forecastCache[event.id] = data;
    } catch (e, st) {
      logger.e('loadWeather failed for ${event.id}: $e\n$st');
      _forecastCache[event.id] = [];
    } finally {
      _loadingIds.remove(event.id);
      if (!disposed) notifyListeners();
    }
  }

  Future<void> onOpenLink(EventViewModel event) async {
    if (event.masterUrl == null || event.masterUrl!.isEmpty) return;

    await _launchUrl(
      Uri.parse(event.masterUrl!),
      event,
      column: 'page_views',
    );
  }

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
        account: auth.currentAccount!,
      );
    } catch (e) {
      logger.e('Failed to increment counter for ${event.id} ($column): $e');
    }
  }

  @override
  void dispose() {
    disposed = true;
    super.dispose();
  }
}
