import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:life_pilot/auth/controller_auth.dart';
import 'package:life_pilot/event/controller_page_event_add.dart';
import 'package:life_pilot/utils/safe_change_notifier.dart';
import 'package:life_pilot/event/model_event.dart';
import 'package:life_pilot/event/model_event_item.dart';
import 'package:life_pilot/event/service_event.dart';
import 'package:life_pilot/event/service_event_public.dart';
import 'package:life_pilot/event/service_event_transfer.dart';
import 'package:life_pilot/event/event_refresh_policy.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/pages/home/service/event_tracking_service.dart';
import 'package:life_pilot/utils/const.dart';
import 'package:life_pilot/utils/date_time.dart';
import 'package:life_pilot/utils/logger.dart';
import 'package:life_pilot/utils/model_event_weather.dart';
import 'package:life_pilot/utils/service/service_weather.dart';
import 'package:url_launcher/url_launcher.dart';

class ControllerEvent extends SafeChangeNotifier {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ControllerAuth auth;
  final ServiceEvent _serviceEvent;
  final ServiceWeather _serviceWeather;
  final ModelEvent _modelEvent;
  final String _tableName;
  final String? _toTableName;
  final ServiceEventTransfer _serviceEventTransfer;
  final ServiceEventPublic _serviceEventPublic;
  final bool _ownsServiceEventPublic;
  final tracking = EventTrackingService();
  final Future<void> Function()? onCalendarReload;
  bool _isLoadingEvents = false;
  Object? _loadEventsError;
  final Set<String> _weatherPreloadAttemptedIds = {};
  Future<void> _weatherPreloadQueue = Future<void>.value();
  int _publicEventServiceOperations = 0;
  bool _publicEventServiceClosed = false;
  int _filterRevision = 0;
  Timer? _searchDebounce;
  DateTime? _memoryLoadedStartDate;
  bool _isLoadingMoreMemory = false;
  bool _hasMoreMemory = true;

  ControllerEvent(
      {required this.auth,
      required ServiceEvent serviceEvent,
      required ServiceWeather serviceWeather,
      required ModelEvent modelEvent,
      required String tableName,
      String? toTableName,
      ServiceEventPublic? serviceEventPublic,
      this.onCalendarReload})
      : _tableName = tableName,
        _toTableName = toTableName,
        _modelEvent = modelEvent,
        _serviceEvent = serviceEvent,
        _serviceWeather = serviceWeather,
        _serviceEventPublic = serviceEventPublic ?? ServiceEventPublic(),
        _ownsServiceEventPublic = serviceEventPublic == null,
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

  EventItem getEventById(String id) {
    return _modelEvent.getEventById(id);
  }

  bool get showSearchPanel => _modelEvent.showSearchPanel;
  ScrollController get scrollController => _scrollController;
  TextEditingController get searchController => _searchController;
  bool get isLoadingEvents => _isLoadingEvents;
  bool get hasLoadEventsError => _loadEventsError != null;
  int get filterRevision => _filterRevision;
  bool get isLoadingMoreMemory => _isLoadingMoreMemory;
  bool get hasMoreMemory => _hasMoreMemory;
  bool get hasActiveSearchFilters {
    final filter = _modelEvent.searchFilter;
    return filter.keywords.isNotEmpty ||
        filter.startDate != null ||
        filter.endDate != null;
  }

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
    if (!_disposed) notifyListeners();
  }

  Future<void> approveEvent({required EventItem event}) async {
    event.isApproved = true;
    event.account = AuthConstants.systemEventOwnerEmail;
    await _serviceEvent.approvalEvent(event: event, tableName: _tableName);
    _invalidateViewModelCache();
    if (!_disposed) notifyListeners();
  }

  void _invalidateViewModelCache() {
    _viewModelCache.clear();
  }

  bool canDelete({required String account}) {
    return auth.currentAccount == account ||
        (auth.isSysAdmin && _tableName != TableNames.memoryTrace);
  }

  Future<void> likeEvent(EventItem event) async {
    final previousLike = event.isLike;
    final previousDislike = event.isDislike;
    event.isLike = event.isLike == true ? false : true;
    event.isDislike = event.isLike == true ? false : event.isDislike;
    _sortRecommendedContent();
    _invalidateViewModelCache();
    if (!_disposed) notifyListeners();
    try {
      await _serviceEvent.updateLikeEvent(
          event: event, account: auth.currentAccount!);
      if (_tableName == TableNames.recommendEvents ||
          _tableName == TableNames.calendarEvents ||
          _tableName == TableNames.memoryTrace) {
        // 🔹 呼叫 function 更新資料庫
        await tracking.incrementEventCounter(
            eventId: event.id,
            eventName: event.name, // 或者用 eventViewModel.name
            column: event.isLike == true ? 'like_counts' : 'card_clicks');
      }
    } catch (_) {
      event.isLike = previousLike;
      event.isDislike = previousDislike;
      _sortRecommendedContent();
      _invalidateViewModelCache();
      if (!_disposed) notifyListeners();
      rethrow;
    }
  }

  Future<void> dislikeEvent(EventItem event) async {
    final previousLike = event.isLike;
    final previousDislike = event.isDislike;
    event.isDislike = event.isDislike == true ? false : true;
    event.isLike = event.isDislike == true ? false : event.isLike;
    _sortRecommendedContent();
    _invalidateViewModelCache();
    if (!_disposed) notifyListeners();
    try {
      await _serviceEvent.updateLikeEvent(
          event: event, account: auth.currentAccount!);
      if (_tableName == TableNames.recommendEvents ||
          _tableName == TableNames.calendarEvents ||
          _tableName == TableNames.memoryTrace) {
        // 🔹 呼叫 function 更新資料庫
        await tracking.incrementEventCounter(
            eventId: event.id,
            eventName: event.name, // 或者用 eventViewModel.name
            column: event.isDislike == true ? 'dislike_counts' : 'card_clicks');
      }
    } catch (_) {
      event.isLike = previousLike;
      event.isDislike = previousDislike;
      _sortRecommendedContent();
      _invalidateViewModelCache();
      if (!_disposed) notifyListeners();
      rethrow;
    }
  }

  bool get _isRecommendedContent =>
      _tableName == TableNames.recommendEvents ||
      _tableName == TableNames.recommendPlaces;

  void _sortRecommendedContent() {
    if (!_isRecommendedContent) return;
    _modelEvent.sortRecommendedContent(
      isEvent: _tableName == TableNames.recommendEvents,
    );
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
    _sortRecommendedContent();
    _invalidateViewModelCache();
    if (!_disposed) notifyListeners();
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
      await tracking.incrementEventCounter(
          eventId: event.id,
          eventName: event.name, // 或者用 eventViewModel.name
          column: 'saves'); //收藏到行事曆
      _invalidateViewModelCache();
    }
    if (!_disposed) notifyListeners();
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
    if (!_disposed) notifyListeners();
  }

  void toggleSearchPanel(bool value, AppLocalizations loc) {
    _modelEvent.toggleSearchPanel(value, loc);
    if (!_disposed) notifyListeners();
  }

  void updateKeywords(
    String? keywords,
  ) {
    _searchDebounce?.cancel();
    _searchDebounce = null;
    _modelEvent.updateSearchKeywords(keywords);
    _filterRevision++;

    final filter = _modelEvent.searchFilter;

    if (keywords == null || keywords.isEmpty) {
      filter.tags.clear();
      _searchController.clear();
      if (!_disposed) notifyListeners();
      return;
    }

    // 如果最後一個字元是空白 → 產生 tag
    final keywordList = keywords
        // ignore: deprecated_member_use
        .split(RegExp(r'[,，\s]+'))
        .map((s) => s
            .trim()) // 只修剪每個 tag 前後空白 .split(RegExp(r'[,，\s]+')) // ← 逗號（英文/中文）或任意空白都分隔
        .where((s) => s.isNotEmpty)
        .toList();
    filter.tags.clear();
    if (keywordList.isNotEmpty) {
      filter.tags = keywordList;
    }
    if (!_disposed) notifyListeners();
    return;
  }

  void updateKeywordsDebounced(String keywords) {
    _searchDebounce?.cancel();
    if (keywords.isEmpty) {
      updateKeywords(null);
      return;
    }
    _searchDebounce = Timer(const Duration(milliseconds: 280), () {
      _searchDebounce = null;
      updateKeywords(keywords);
    });
  }

  void removeKeywordTag(String tag) {
    final keywords =
        _modelEvent.searchFilter.tags.where((item) => item != tag).join(' ');
    _searchController.text = keywords;
    updateKeywords(keywords.isEmpty ? null : keywords);
  }

  void clearSearchFilters() {
    _searchDebounce?.cancel();
    _searchDebounce = null;
    _modelEvent.clearSearchAll();
    _searchController.clear();
    _filterRevision++;
    if (!_disposed) notifyListeners();
  }

  void updateStartDate(
    DateTime? startDate,
  ) {
    _modelEvent.updateStartDate(startDate);
    _filterRevision++;
    if (!_disposed) notifyListeners();
  }

  void updateEndDate(
    DateTime? endDate,
  ) {
    _modelEvent.updateEndDate(endDate);
    _filterRevision++;
    if (!_disposed) notifyListeners();
  }

  // 判斷日期是否要顯示
  bool showDate() {
    return _tableName != TableNames.recommendPlaces;
  }

  final Map<
      String,
      ({
        EventItem event,
        AppLocalizations loc,
        EventViewModel viewModel,
      })> _viewModelCache = {};

  EventViewModel buildViewModel({
    required EventItem event,
    required AppLocalizations loc,
  }) {
    final cached = _viewModelCache[event.id];
    if (cached != null &&
        identical(cached.event, event) &&
        identical(cached.loc, loc)) {
      return cached.viewModel;
    }

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

    _viewModelCache[event.id] = (
      event: event,
      loc: loc,
      viewModel: tmp,
    );
    return tmp;
  }

  Future<void> loadEvents({required bool isGetPublicEvents}) async {
    if (_isLoadingEvents) return;
    _isLoadingEvents = true;
    _loadEventsError = null;
    if (!_disposed) notifyListeners();

    try {
      final today = DateTimeFormatter.dateOnly(DateTime.now());
      final isMemoryTrace = _tableName == TableNames.memoryTrace;
      final memoryStart = today.subtract(const Duration(days: 29));
      final list = await _serviceEvent.getEvents(
        tableName: _tableName,
        inputUser: auth.currentAccount,
        dateS: isMemoryTrace ? memoryStart : null,
        dateE: isMemoryTrace ? today : null,
      );
      _modelEvent.setEvents(list ?? []);
      _sortRecommendedContent();
      if (isMemoryTrace) {
        _modelEvent.sortMemoryEvents();
        _memoryLoadedStartDate = memoryStart;
        _hasMoreMemory = await _serviceEvent.hasEventsBefore(
          tableName: _tableName,
          before: memoryStart,
          inputUser: auth.currentAccount,
        );
      }

      // ✅ STOP UI card 不再觸發 weather
      _invalidateViewModelCache();
    } catch (error, stackTrace) {
      _loadEventsError = error;
      logger.e(
        'loadEvents failed for $_tableName',
        error: error,
        stackTrace: stackTrace,
      );
    } finally {
      _isLoadingEvents = false;
      if (!_disposed) notifyListeners();
    }

    if (_loadEventsError != null) return;

    if (isGetPublicEvents &&
        !_disposed &&
        auth.isSysAdmin &&
        _tableName == TableNames.recommendEvents) {
      _beginPublicEventServiceOperation();
      try {
        await _serviceEventPublic.fetchAndSaveAllEvents();

        final newList = await _serviceEvent.getEvents(
          tableName: _tableName,
          inputUser: auth.currentAccount,
        );

        _modelEvent.setEvents(newList ?? []);
        _sortRecommendedContent();
        _invalidateViewModelCache();
        if (!_disposed) notifyListeners();
      } catch (error, stackTrace) {
        logger.e(
          'public event refresh failed after loading existing events',
          error: error,
          stackTrace: stackTrace,
        );
      } finally {
        _endPublicEventServiceOperation();
      }
    }
  }

  Future<void> loadMoreMemoryEvents() async {
    if (_tableName != TableNames.memoryTrace ||
        _isLoadingMoreMemory ||
        !_hasMoreMemory) {
      return;
    }
    final loadedStart = _memoryLoadedStartDate ??
        DateTimeFormatter.dateOnly(DateTime.now())
            .subtract(const Duration(days: 29));
    _isLoadingMoreMemory = true;
    if (!_disposed) notifyListeners();
    try {
      final latestOlder = await _serviceEvent.latestEventDateBefore(
        tableName: _tableName,
        before: loadedStart,
        inputUser: auth.currentAccount,
      );
      if (latestOlder == null) {
        _hasMoreMemory = false;
        return;
      }
      final rangeEnd = DateTimeFormatter.dateOnly(latestOlder);
      final rangeStart = rangeEnd.subtract(const Duration(days: 29));
      final olderEvents = await _serviceEvent.getEvents(
            tableName: _tableName,
            inputUser: auth.currentAccount,
            dateS: rangeStart,
            dateE: rangeEnd,
          ) ??
          [];
      _modelEvent.appendMemoryEvents(olderEvents);
      _memoryLoadedStartDate = rangeStart;
      _hasMoreMemory = await _serviceEvent.hasEventsBefore(
        tableName: _tableName,
        before: rangeStart,
        inputUser: auth.currentAccount,
      );
      _invalidateViewModelCache();
    } finally {
      _isLoadingMoreMemory = false;
      if (!_disposed) notifyListeners();
    }
  }

  void preloadWeatherForEvent(EventViewModel event) {
    if (!_weatherPreloadAttemptedIds.add(event.id)) return;
    _weatherPreloadQueue = _weatherPreloadQueue
        .then((_) => _preloadWeatherForEvent(event))
        .catchError((_) {});
  }

  Future<void> _preloadWeatherForEvent(EventViewModel event) async {
    if (_disposed) return;
    final requested = await _serviceWeather.preloadWeather(
      [event],
      tableName: _tableName,
    );
    if (requested) {
      if (!_disposed) notifyListeners();
      await Future.delayed(const Duration(seconds: 1));
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
      await tracking.incrementEventCounter(
        eventId: event.id,
        eventName: event.name,
        column: column,
      );
    } catch (e) {
      logger.e('Failed to increment counter for ${event.id} ($column): $e');
    }
  }

  bool _isRefreshingPublicEvents = false;
  bool get isRefreshingPublicEvents => _isRefreshingPublicEvents;
  bool _publicEventsUpdatedToday = false;
  bool _publicEventsRefreshRunning = false;
  bool get publicEventsRefreshRunning => _publicEventsRefreshRunning;
  bool _hasCheckedPublicEventsUpdate = false;

  bool get canRefreshPublicEvents {
    return EventRefreshPolicy.canRefresh(
      tableName: _tableName,
      isAdmin: auth.isSysAdmin,
      isWeb: kIsWeb,
      platform: defaultTargetPlatform,
      hasCheckedUpdate: _hasCheckedPublicEventsUpdate,
      updatedToday: _publicEventsUpdatedToday,
      isRunning: _publicEventsRefreshRunning,
    );
  }

  Future<void> checkPublicEventsUpdatedToday() async {
    if (_tableName != TableNames.recommendEvents || _disposed) return;
    _beginPublicEventServiceOperation();
    try {
      final status = await _serviceEventPublic.getRefreshStatus();
      _publicEventsUpdatedToday = status.updated;
      _publicEventsRefreshRunning = status.running;
    } catch (error, stackTrace) {
      logger.e(
        'checkPublicEventsUpdatedToday failed',
        error: error,
        stackTrace: stackTrace,
      );
      _publicEventsUpdatedToday = false;
      _publicEventsRefreshRunning = false;
    } finally {
      _endPublicEventServiceOperation();
    }
    _hasCheckedPublicEventsUpdate = true;
    if (!_disposed) notifyListeners();
  }

  Future<bool> refreshPublicEvents() async {
    if (!canRefreshPublicEvents || _isRefreshingPublicEvents || _disposed) {
      return false;
    }

    _isRefreshingPublicEvents = true;
    _beginPublicEventServiceOperation();
    notifyListeners();
    try {
      final execution = await _serviceEventPublic.fetchAndSaveAllEvents();
      if (execution == PublicEventRefreshExecution.running) {
        _publicEventsRefreshRunning = true;
        _hasCheckedPublicEventsUpdate = true;
        return false;
      }
      final newList = await _serviceEvent.getEvents(
        tableName: _tableName,
        inputUser: auth.currentAccount,
      );
      _modelEvent.setEvents(newList ?? []);
      _invalidateViewModelCache();
      final status = await _serviceEventPublic.getRefreshStatus();
      _publicEventsUpdatedToday = status.updated;
      _publicEventsRefreshRunning = status.running;
      _hasCheckedPublicEventsUpdate = true;
      if (!_disposed) notifyListeners();
      return _publicEventsUpdatedToday;
    } catch (error, stackTrace) {
      logger.e(
        'refreshPublicEvents failed',
        error: error,
        stackTrace: stackTrace,
      );
      return false;
    } finally {
      _isRefreshingPublicEvents = false;
      _endPublicEventServiceOperation();
      if (!_disposed) notifyListeners();
    }
  }

  void _beginPublicEventServiceOperation() {
    _publicEventServiceOperations++;
  }

  void _endPublicEventServiceOperation() {
    if (_publicEventServiceOperations > 0) {
      _publicEventServiceOperations--;
    }
    _closePublicEventServiceIfIdle();
  }

  void _closePublicEventServiceIfIdle() {
    if (!_disposed ||
        !_ownsServiceEventPublic ||
        _publicEventServiceClosed ||
        _publicEventServiceOperations > 0) {
      return;
    }
    _publicEventServiceClosed = true;
    _serviceEventPublic.close();
  }

  bool _disposed = false;
  @override
  void dispose() {
    _disposed = true;
    _searchDebounce?.cancel();
    _closePublicEventServiceIfIdle();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}
