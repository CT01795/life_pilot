import 'package:flutter/material.dart';
import 'package:life_pilot/auth/controller_auth.dart';
import 'package:life_pilot/event/model_event.dart';
import 'package:life_pilot/event/controller_page_event_add.dart';
import 'package:life_pilot/event/service_event_public.dart';
import 'package:life_pilot/utils/const.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/event/model_event_item.dart';
import 'package:life_pilot/event/service_event.dart';
import 'package:life_pilot/event/service_event_transfer.dart';
import 'package:life_pilot/utils/logger.dart';
import 'package:life_pilot/utils/model_event_weather.dart';
import 'dart:async';
import 'package:life_pilot/utils/service/service_weather.dart';
import 'package:url_launcher/url_launcher.dart';

class ControllerEvent extends ChangeNotifier {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ControllerAuth auth;
  final ServiceEvent _serviceEvent;
  final ServiceWeather _serviceWeather;
  final ModelEvent _modelEvent;
  final String _tableName;
  final String? _toTableName;
  final ServiceEventTransfer _serviceEventTransfer;
  final Future<void> Function()? onCalendarReload;

  ControllerEvent(
      {required this.auth,
      required ServiceEvent serviceEvent,
      required ServiceWeather serviceWeather,
      required ModelEvent modelEvent,
      required String tableName,
      String? toTableName,
      this.onCalendarReload})
      : _tableName = tableName,
        _toTableName = toTableName,
        _modelEvent = modelEvent,
        _serviceEvent = serviceEvent,
        _serviceWeather = serviceWeather,
        _serviceEventTransfer = ServiceEventTransfer(
            currentAccount: auth.currentAccount ?? '',
            serviceEvent: serviceEvent);

  ServiceEvent get serviceEvent => _serviceEvent;
  ServiceWeather get serviceWeather => _serviceWeather;
  String get fromTableName => _tableName;
  ModelEvent get modelEvent => _modelEvent;
  List<EventItem> getFilteredEvents(AppLocalizations loc) =>
      _modelEvent.getFilteredEvents(loc);
  bool isEventSelected(String eventId) {
    return _modelEvent.selectedEventIds.contains(eventId);
  }

  bool get showSearchPanel => _modelEvent.showSearchPanel;
  ScrollController get scrollController => _scrollController;
  TextEditingController get searchController => _searchController;

  // ---------------------------------------------------------------------------
  // 📦 CRUD 操作
  // ---------------------------------------------------------------------------
  Future<void> saveEvent({
    EventItem? oldEvent,
    required EventItem newEvent,
    bool isNew = true,
  }) async {
    await _serviceEvent.saveEvent(
        currentAccount: auth.currentAccount ?? '',
        event: newEvent,
        isNew: isNew,
        tableName: _tableName);
  }

  // ✅ 刪除事件，並更新列表與通知 UI
  Future<void> deleteEvent(EventItem event) async {
    await _serviceEvent.deleteEvent(
        currentAccount: auth.currentAccount ?? '',
        event: event,
        tableName: _tableName);

    // 移除事件並更新快取
    _modelEvent
      ..removeEvent(event)
      ..markRemoved(event.id);
    _invalidateViewModelCache();
    notifyListeners();
  }

  Future<void> approveEvent({required EventItem event}) async {
    event.isApproved = true;
    event.account = AuthConstants.sysAdminEmail;
    await _serviceEvent.approvalEvent(event: event, tableName: _tableName);
    _invalidateViewModelCache();
    notifyListeners();
  }

  void _invalidateViewModelCache() {
    _cachedViewModels = null;
    _lastEvents = null;
  }

  bool canDelete({required String account}) {
    return auth.currentAccount == account ||
        (auth.currentAccount == AuthConstants.sysAdminEmail &&
            _tableName != TableNames.memoryTrace);
  }

  Future<void> likeEvent(EventItem event) async {
    event.isLike = event.isLike == true ? false : true;
    event.isDislike = event.isLike == true ? false : event.isDislike;
    await _serviceEvent.updateLikeEvent(
        event: event, account: auth.currentAccount!);
    if (_tableName == TableNames.recommendedEvents ||
        _tableName == TableNames.calendarEvents ||
        _tableName == TableNames.memoryTrace) {
      // 🔹 呼叫 function 更新資料庫
      await _serviceEvent.incrementEventCounter(
          eventId: event.id,
          eventName: event.name, // 或者用 eventViewModel.name
          column: event.isLike == true ? 'like_counts' : 'card_clicks',
          account: auth.currentAccount ?? AuthConstants.guest);
    }
    _invalidateViewModelCache();
    notifyListeners();
  }

  Future<void> dislikeEvent(EventItem event) async {
    event.isDislike = event.isDislike == true ? false : true;
    event.isLike = event.isDislike == true ? false : event.isLike;
    await _serviceEvent.updateLikeEvent(
        event: event, account: auth.currentAccount!);
    if (_tableName == TableNames.recommendedEvents ||
        _tableName == TableNames.calendarEvents ||
        _tableName == TableNames.memoryTrace) {
      // 🔹 呼叫 function 更新資料庫
      await _serviceEvent.incrementEventCounter(
          eventId: event.id,
          eventName: event.name, // 或者用 eventViewModel.name
          column: event.isDislike == true ? 'dislike_counts' : 'card_clicks',
          account: auth.currentAccount ?? AuthConstants.guest);
    }
    _invalidateViewModelCache();
    notifyListeners();
  }

  // ✅ 建立單筆事件控制器
  ControllerPageEventAdd createAddController({
    EventItem? existingEvent,
    DateTime? initialDate,
  }) {
    return ControllerPageEventAdd(
      auth: auth,
      tableName: _tableName,
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
    _modelEvent.updateEvent(updatedEvent);
    _invalidateViewModelCache();
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // 🔄 資料轉移（跨 Table）
  // ---------------------------------------------------------------------------
  // ✅ Checkbox 點擊事件處理
  Future<bool> handleEventCheckboxIsAlreadyAdd(
    EventItem event,
    bool isChecked,
  ) async {
    // 先更新 UI
    toggleEventSelection(event.id, isChecked);

    return await _serviceEventTransfer.toggleEventTransferIsAlreadyAdd(
        event: event, toTableName: _toTableName!, isChecked: isChecked);
  }

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
      toTableName: _toTableName!,
    );
    _modelEvent.toggleEventSelection(event.id, targetEvent != null);
    if (targetEvent != null && _toTableName == TableNames.calendarEvents) {
      // 🔹 呼叫 function 更新資料庫
      await _serviceEvent.incrementEventCounter(
          eventId: event.id,
          eventName: event.name, // 或者用 eventViewModel.name
          column: 'saves', //收藏到行事曆
          account: auth.currentAccount ?? AuthConstants.guest);
      _invalidateViewModelCache();
    }
    notifyListeners();
    return targetEvent;
  }

  String buildTransferMessage({
    required bool isAlreadyAdded,
    required EventItem event,
    required AppLocalizations loc,
  }) {
    if (isAlreadyAdded) {
      return _tableName == TableNames.calendarEvents
          ? loc.memoryAddError
          : loc.eventAddError;
    } else {
      return '${_tableName == TableNames.calendarEvents ? loc.memoryAdd : loc.eventAdd}「${event.name}」？';
    }
  }

  // ---------------------------------------------------------------------------
  // 🔍 搜尋與篩選控制
  // ---------------------------------------------------------------------------
  void toggleEventSelection(String eventId, bool isSelected) {
    _modelEvent.toggleEventSelection(eventId, isSelected);
    notifyListeners();
  }

  void toggleSearchPanel(bool value) {
    _modelEvent.toggleSearchPanel(value);
    notifyListeners();
  }

  void updateKeywords(
    String? keywords,
  ) {
    _modelEvent.updateSearchKeywords(keywords);

    final filter = _modelEvent.searchFilter;

    if (keywords == null || keywords.isEmpty) {
      filter.tags.clear();
      _searchController.clear();
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
    _modelEvent.updateStartDate(startDate);
    notifyListeners();
  }

  void updateEndDate(
    DateTime? endDate,
  ) {
    _modelEvent.updateEndDate(endDate);
    notifyListeners();
  }

  // 判斷日期是否要顯示
  bool showDate() {
    return _tableName != TableNames.recommendedAttractions;
  }

  List<EventViewModel>? _cachedViewModels;
  List<EventItem>? _lastEvents;

  List<EventViewModel> buildViewModels({
    required List<EventItem> events,
    required AppLocalizations loc,
  }) {
    if (_cachedViewModels != null && identical(_lastEvents, events)) {
      return _cachedViewModels!;
    }

    _lastEvents = events;

    _cachedViewModels =
        events.map((event) => buildViewModel(event: event, loc: loc)).toList();
    return _cachedViewModels!;
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

  Future<void> loadEvents({required bool isGetPublicEvents}) async {
    if(isGetPublicEvents) await ServiceEventPublic().fetchAndSaveAllEvents();

    final list = await _serviceEvent.getEvents(
      tableName: _tableName,
      inputUser: auth.currentAccount,
    );
    _modelEvent.setEvents(list ?? []);
    _invalidateViewModelCache();
    notifyListeners();
  }

  // ------------------ controller event card ------------------
  // ------------------ Public ------------------
  List<EventWeather>? getForecast(String eventId) {
    return _serviceWeather.getForecast(eventId);
  }

  // 取得天氣預報（緩存）
  Future<List<EventWeather>?> loadWeather(EventViewModel event) async {
    return await _serviceWeather.loadWeather(
      eventId: event.id,
      hasLocation: event.hasLocation,
      locationDisplay: event.locationDisplay,
      startDate: event.startDate,
      endDate: event.endDate,
      tableName: _tableName,
    );
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
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}
