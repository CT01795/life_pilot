import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:life_pilot/auth/controller_auth.dart';
import 'package:life_pilot/event/controller_page_event_add.dart';
import 'package:life_pilot/utils/safe_change_notifier.dart';
import 'package:life_pilot/event/model_event.dart';
import 'package:life_pilot/event/model_event_item.dart';
import 'package:life_pilot/event/model_event_page.dart';
import 'package:life_pilot/event/model_event_load_policy.dart';
import 'package:life_pilot/event/model_event_preference.dart';
import 'package:life_pilot/event/model_event_view_cache.dart';
import 'package:life_pilot/event/public_event_refresh.dart';
import 'package:life_pilot/event/service_event.dart';
import 'package:life_pilot/event/service_event_public.dart';
import 'package:life_pilot/event/service_event_transfer.dart';
import 'package:life_pilot/event/event_refresh_policy.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/event/service_event_tracking.dart';
import 'package:life_pilot/utils/const.dart';
import 'package:life_pilot/utils/date_time.dart';
import 'package:life_pilot/utils/logger.dart';
import 'package:life_pilot/utils/model_event_weather.dart';
import 'package:life_pilot/utils/service/service_weather.dart';

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
  final EventTrackingService tracking;
  final Future<void> Function()? onCalendarReload;
  bool _isLoadingEvents = false;
  bool _isLoadingMemoryRecords = false;
  bool _hasLoadedEventsSuccessfully = false;
  Object? _loadEventsError;
  final Set<String> _weatherPreloadAttemptedIds = {};
  final Map<String, EventViewModel> _pendingWeatherPreloads = {};
  Future<void> _weatherPreloadQueue = Future<void>.value();
  Timer? _weatherPreloadDebounce;
  int _publicEventServiceOperations = 0;
  bool _publicEventServiceClosed = false;
  int _filterRevision = 0;
  Timer? _searchDebounce;
  DateTime? _memoryLoadedStartDate;
  DateTime? _memoryLoadedEndDate;
  bool _isLoadingMoreMemory = false;
  bool _isCheckingMoreMemory = false;
  bool _hasMoreMemory = true;
  // Memory rows can include embedded photos. Keep their logical page smaller
  // without changing the date window or the recommended-content page size.
  int get _cloudPageSize =>
      ModelEventLoadPolicy.forTable(_tableName).cloudPageSize;
  int _nextCloudOffset = 0;
  bool _isLoadingMoreEvents = false;
  bool _hasMoreEvents = true;
  late String _dataScopeKey;
  int _dataScopeGeneration = 0;
  final Set<String> _pendingPreferences = {};
  Future<void>? _pageInitialization;

  ControllerEvent({
    required this.auth,
    required ServiceEvent serviceEvent,
    required ServiceWeather serviceWeather,
    required ModelEvent modelEvent,
    required String tableName,
    String? toTableName,
    ServiceEventPublic? serviceEventPublic,
    this.onCalendarReload,
    EventTrackingService? eventTracking,
  }) : tracking = eventTracking ?? EventTrackingService(),
       _tableName = tableName,
       _toTableName = toTableName,
       _modelEvent = modelEvent,
       _serviceEvent = serviceEvent,
       _serviceWeather = serviceWeather,
       _serviceEventPublic = serviceEventPublic ?? ServiceEventPublic(),
       _ownsServiceEventPublic = serviceEventPublic == null,
       _serviceEventTransfer = ServiceEventTransfer(
         currentAccount: auth.currentAccount ?? '',
         serviceEvent: serviceEvent,
       ) {
    _dataScopeKey = _currentDataScopeKey;
    auth.addListener(_handleAuthChange);
  }

  String get _currentDataScopeKey =>
      '${auth.currentAccount ?? ''}|${auth.preferredStorage.name}';

  void _handleAuthChange() {
    final nextKey = _currentDataScopeKey;
    if (nextKey == _dataScopeKey) return;
    _dataScopeKey = nextKey;
    _dataScopeGeneration++;
    _pageInitialization = null;
    _isRefreshingPublicEvents = false;
    _hasCheckedPublicEventsUpdate = false;
    _publicEventsUpdatedToday = false;
    _publicEventsRefreshRunning = false;
    _isLoadingEvents = false;
    _isLoadingMemoryRecords = false;
    _isLoadingMoreMemory = false;
    _isCheckingMoreMemory = false;
    _isLoadingMoreEvents = false;
    _hasLoadedEventsSuccessfully = false;
    _loadEventsError = null;
    _memoryLoadedStartDate = null;
    _memoryLoadedEndDate = null;
    _hasMoreMemory = true;
    _hasMoreEvents = true;
    _nextCloudOffset = 0;
    _weatherPreloadDebounce?.cancel();
    _pendingWeatherPreloads.clear();
    _weatherPreloadAttemptedIds.clear();
    // A new scope must not wait for an old in-flight network request. Existing
    // queue callbacks retain their generation and will skip stale work.
    _weatherPreloadQueue = Future<void>.value();
    _invalidateViewModelCache();
    _modelEvent.resetForDataScope();
    if (!_disposed) notifyListeners();
  }

  bool _isCurrentDataScope(int generation) =>
      !_disposed &&
      generation == _dataScopeGeneration &&
      _dataScopeKey == _currentDataScopeKey;

  ServiceEvent get serviceEvent => _serviceEvent;
  ServiceWeather get serviceWeather => _serviceWeather;
  String get fromTableName => _tableName;
  ModelEvent get modelEvent => _modelEvent;
  List<EventItem> getFilteredEvents(AppLocalizations loc) =>
      _modelEvent.getFilteredEvents(loc);
  bool isEventSelected(String eventId) {
    return _modelEvent.selectedEventIds.contains(eventId);
  }

  EventItem? findEventById(String id) {
    return _modelEvent.findEventById(id);
  }

  bool get showSearchPanel => _modelEvent.showSearchPanel;
  ScrollController get scrollController => _scrollController;
  TextEditingController get searchController => _searchController;
  bool get isLoadingEvents => _isLoadingEvents;
  bool get isLoadingMemoryRecords => _isLoadingMemoryRecords;
  bool get hasLoadedEventsSuccessfully => _hasLoadedEventsSuccessfully;
  bool get hasLoadEventsError => _loadEventsError != null;
  int get filterRevision => _filterRevision;
  bool get isLoadingMoreMemory =>
      _isLoadingMoreMemory ||
      _isCheckingMoreMemory ||
      (_tableName == TableNames.memoryTrace && _isLoadingEvents);
  bool get hasMoreMemory => _hasMoreMemory;
  bool get isLoadingMoreEvents => _isLoadingMoreEvents;
  bool get hasMoreEvents => _hasMoreEvents;
  bool get usesCloudPagination =>
      _isRecommendedContent ||
      (!auth.storesNewDataLocally && _tableName == TableNames.memoryTrace);
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
    if (_disposed) return;
    _handleAuthChange();
    final generation = _dataScopeGeneration;
    final account = auth.currentAccount ?? '';
    await _serviceEvent.saveEvent(
      currentAccount: account,
      event: newEvent,
      isNew: isNew,
      tableName: _tableName,
      originalAccount: oldEvent?.account,
      originalIsApproved: oldEvent?.isApproved,
    );
    if (!_isCurrentDataScope(generation)) return;
    if (isNew &&
        (_tableName == TableNames.calendarEvents ||
            _tableName == TableNames.memoryTrace)) {
      await auth.refreshSubscriptionUsage();
    }
  }

  // ✅ 刪除事件，並更新列表與通知 UI
  Future<void> deleteEvent(EventItem event) async {
    if (_disposed) return;
    _handleAuthChange();
    final generation = _dataScopeGeneration;
    final account = auth.currentAccount ?? '';
    await _serviceEvent.deleteEvent(
      currentAccount: account,
      event: event,
      tableName: _tableName,
    );
    if (!_isCurrentDataScope(generation)) return;
    if (_tableName == TableNames.calendarEvents ||
        _tableName == TableNames.memoryTrace) {
      await auth.refreshSubscriptionUsage();
    }

    // Quota refresh can also outlive an account or storage-mode change.
    if (!_isCurrentDataScope(generation)) return;

    // 移除事件並更新快取
    _modelEvent
      ..removeEvent(event)
      ..markRemoved(event.id);
    _invalidateViewModel(event.id);
    if (!_disposed) notifyListeners();
  }

  Future<void> approveEvent({required EventItem event}) async {
    if (_disposed) return;
    _handleAuthChange();
    final generation = _dataScopeGeneration;
    await _serviceEvent.approvalEvent(eventId: event.id, tableName: _tableName);
    if (!_isCurrentDataScope(generation)) return;
    event.isApproved = true;
    _invalidateViewModel(event.id);
    if (!_disposed) notifyListeners();
  }

  void _invalidateViewModelCache() {
    _viewModelCache.clear();
  }

  void _invalidateViewModel(String eventId) {
    _viewModelCache.invalidate(eventId);
  }

  bool canDelete({required String account, bool isApproved = false}) {
    final isRecommendedContent =
        _tableName == TableNames.recommendEvents ||
        _tableName == TableNames.recommendPlaces;
    if (isRecommendedContent && isApproved && !auth.isSysAdmin) {
      return false;
    }
    return auth.currentAccount == account ||
        (auth.isSysAdmin && _tableName != TableNames.memoryTrace);
  }

  Future<void> likeEvent(EventItem event) =>
      _changePreference(event, EventPreferenceAction.like);

  Future<void> dislikeEvent(EventItem event) =>
      _changePreference(event, EventPreferenceAction.dislike);

  Future<void> _changePreference(
    EventItem event,
    EventPreferenceAction action,
  ) async {
    if (_disposed) return;
    _handleAuthChange();
    final generation = _dataScopeGeneration;
    final account = auth.currentAccount;
    if (account == null ||
        account.isEmpty ||
        !_isCurrentDataScope(generation)) {
      return;
    }
    final requestKey = '$generation|${event.id}';
    if (!_pendingPreferences.add(requestKey)) return;
    final previous = ModelEventPreference.fromEvent(event);
    final updated = previous.toggle(action);
    updated.applyTo(event);
    _sortRecommendedContent();
    _invalidateViewModel(event.id);
    if (!_disposed) notifyListeners();
    // A synchronous listener can switch accounts while publishing the change.
    try {
      if (!_isCurrentDataScope(generation)) return;
      // Persist the requested snapshot, not a mutable card that may change later.
      // The database saves preferences and adjusts both counters atomically.
      await _serviceEvent.updateLikeEvent(
        event: event.copyWith(
          newIsLike: updated.isLike,
          newIsDislike: updated.isDislike,
        ),
        account: account,
        tableName: _tableName,
      );
    } catch (_) {
      if (!_isCurrentDataScope(generation)) rethrow;
      previous.applyTo(event);
      _sortRecommendedContent();
      _invalidateViewModel(event.id);
      if (!_disposed) notifyListeners();
      rethrow;
    } finally {
      _pendingPreferences.remove(requestKey);
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
    EventItem? templateEvent,
    DateTime? initialDate,
  }) {
    return ControllerPageEventAdd(
      auth: auth,
      tableName: _tableName,
      existingEvent: existingEvent,
      templateEvent: templateEvent,
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
    _invalidateViewModel(event.id);
    if (updatedEvent.id != event.id) {
      _invalidateViewModel(updatedEvent.id);
    }
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
      event: event,
      toTableName: _toTableName!,
      isChecked: isChecked,
    );
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
      await auth.refreshSubscriptionUsage();
      // 🔹 呼叫 function 更新資料庫
      await tracking.incrementEventCounter(
        eventId: event.id,
        eventName: event.name, // 或者用 eventViewModel.name
        column: 'saves',
      ); //收藏到行事曆
      _invalidateViewModel(event.id);
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

  void updateKeywords(String? keywords) {
    _searchDebounce?.cancel();
    _searchDebounce = null;
    _modelEvent.updateSearchKeywords(keywords);
    _filterRevision++;

    if (keywords == null || keywords.isEmpty) {
      _searchController.clear();
      if (!_disposed) notifyListeners();
      return;
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
    final keywords = _modelEvent.searchFilter.tags
        .where((item) => item != tag)
        .join(' ');
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

  void updateStartDate(DateTime? startDate) {
    _modelEvent.updateStartDate(startDate);
    _filterRevision++;
    if (!_disposed) notifyListeners();
  }

  void updateEndDate(DateTime? endDate) {
    _modelEvent.updateEndDate(endDate);
    _filterRevision++;
    if (!_disposed) notifyListeners();
  }

  // 判斷日期是否要顯示
  bool showDate() {
    return _tableName != TableNames.recommendPlaces;
  }

  final _viewModelCache = ModelEventViewCache();

  EventViewModel buildViewModel({
    required EventItem event,
    required AppLocalizations loc,
  }) {
    return _viewModelCache.build(
      event: event,
      canDelete: canDelete(
        account: event.account ?? '',
        isApproved: event.isApproved,
      ),
      loc: loc,
      tableName: _tableName,
    );
  }

  /// Own page-entry orchestration here rather than in individual views.
  Future<void> initializePage({bool autoRefreshPublicEvents = false}) {
    _handleAuthChange();
    if (_disposed) return Future<void>.value();
    final pending = _pageInitialization;
    if (pending != null) return pending;
    final generation = _dataScopeGeneration;
    final completion = Completer<void>();
    final operation = completion.future;
    _pageInitialization = operation;
    unawaited(
      _initializePage(generation, autoRefreshPublicEvents).then(
        (_) {
          if (identical(_pageInitialization, operation)) {
            _pageInitialization = null;
          }
          completion.complete();
        },
        onError: (Object error, StackTrace stackTrace) {
          if (identical(_pageInitialization, operation)) {
            _pageInitialization = null;
          }
          completion.completeError(error, stackTrace);
        },
      ),
    );
    return operation;
  }

  Future<void> _initializePage(int generation, bool autoRefresh) async {
    await loadEvents(isGetPublicEvents: false);
    if (!_isCurrentDataScope(generation)) return;
    await checkPublicEventsUpdatedToday();
    if (!_isCurrentDataScope(generation)) return;
    if (autoRefresh && canRefreshPublicEvents) await refreshPublicEvents();
  }

  List<EventItem> _acceptCloudPage(List<EventItem> rows, {int offset = 0}) {
    final page = ModelEventPage.fromRows(
      rows,
      pageSize: _cloudPageSize,
      offset: offset,
    );
    _hasMoreEvents = page.hasMore;
    _nextCloudOffset = page.nextOffset;
    return page.events;
  }

  Future<void> loadEvents({required bool isGetPublicEvents}) async {
    _handleAuthChange();
    if (_isLoadingEvents) return;
    final generation = _dataScopeGeneration;
    _isLoadingEvents = true;
    _isLoadingMemoryRecords = _tableName == TableNames.memoryTrace;
    _loadEventsError = null;
    if (!_disposed) notifyListeners();

    try {
      final today = DateTimeFormatter.dateOnly(DateTime.now());
      final isMemoryTrace = _tableName == TableNames.memoryTrace;
      final memoryStart = today.subtract(const Duration(days: 29));
      void publishMemoryPreview(List<EventItem> rows) {
        if (!_isCurrentDataScope(generation) || rows.isEmpty) return;
        // Keep the service's accumulating buffer separate from model sorting.
        final preview = rows.take(_cloudPageSize).toList();
        _modelEvent.setProgressiveEvents(preview);
        _modelEvent.sortMemoryEvents();
        _hasLoadedEventsSuccessfully = true;
        _hasMoreMemory = true;
        _viewModelCache.retainEvents(preview);
        notifyListeners();
      }

      // Continuations must use exactly the same upper bound as the first query,
      // which also includes memories entered for a future date.
      _memoryLoadedEndDate = isMemoryTrace
          ? DateTime(today.year + 2, today.month, today.day)
          : null;
      final list = await _serviceEvent.getEvents(
        tableName: _tableName,
        inputUser: auth.currentAccount,
        storageLocation: auth.preferredStorage,
        dateS: isMemoryTrace ? memoryStart : null,
        dateE: isMemoryTrace ? _memoryLoadedEndDate : null,
        limit: usesCloudPagination ? _cloudPageSize + 1 : null,
        onPartialEvents: isMemoryTrace ? publishMemoryPreview : null,
        shouldContinue: () => _isCurrentDataScope(generation),
      );
      if (!_isCurrentDataScope(generation)) return;
      var loadedEvents = list ?? [];
      if (usesCloudPagination) {
        loadedEvents = _acceptCloudPage(loadedEvents);
      } else {
        _hasMoreEvents = false;
        _nextCloudOffset = 0;
      }
      if (isMemoryTrace && loadedEvents.isEmpty) {
        final latestOlder = await _serviceEvent.latestEventDateBefore(
          tableName: _tableName,
          before: memoryStart,
          inputUser: auth.currentAccount,
          storageLocation: auth.preferredStorage,
          onLatestEvent: (event) => publishMemoryPreview([event]),
        );
        if (!_isCurrentDataScope(generation)) return;
        if (latestOlder != null) {
          _memoryLoadedEndDate = latestOlder;
          loadedEvents =
              await _serviceEvent.getEvents(
                tableName: _tableName,
                inputUser: auth.currentAccount,
                storageLocation: auth.preferredStorage,
                dateS: latestOlder,
                dateE: latestOlder,
                limit: usesCloudPagination ? _cloudPageSize + 1 : null,
                onPartialEvents: publishMemoryPreview,
                shouldContinue: () => _isCurrentDataScope(generation),
              ) ??
              [];
          if (!_isCurrentDataScope(generation)) return;
          if (usesCloudPagination) {
            loadedEvents = _acceptCloudPage(loadedEvents);
          }
        }
      }
      _isLoadingMemoryRecords = false;
      if (isMemoryTrace) {
        _modelEvent.setProgressiveEvents(loadedEvents);
      } else {
        _modelEvent.setEvents(loadedEvents);
      }
      _hasLoadedEventsSuccessfully = true;
      _sortRecommendedContent();
      if (isMemoryTrace) {
        _modelEvent.sortMemoryEvents();
        _memoryLoadedStartDate = memoryStart;
        if (loadedEvents.isNotEmpty &&
            loadedEvents.every(
              (event) =>
                  event.startDate != null &&
                  event.startDate!.isBefore(memoryStart),
            )) {
          _memoryLoadedStartDate = DateTimeFormatter.dateOnly(
            loadedEvents
                .map((event) => event.startDate!)
                .reduce((left, right) => left.isBefore(right) ? left : right),
          );
        }
        if (usesCloudPagination && _hasMoreEvents) {
          _hasMoreMemory = true;
        } else {
          // The content is ready. Publish it before this optional metadata query.
          _hasMoreMemory = true;
          _isCheckingMoreMemory = true;
          _viewModelCache.retainEvents(loadedEvents);
          notifyListeners();
          if (!_isCurrentDataScope(generation)) return;
          try {
            final hasOlder = await _serviceEvent
                .hasEventsBefore(
                  tableName: _tableName,
                  before: _memoryLoadedStartDate ?? memoryStart,
                  inputUser: auth.currentAccount,
                  storageLocation: auth.preferredStorage,
                )
                .timeout(const Duration(seconds: 10));
            if (!_isCurrentDataScope(generation)) return;
            _hasMoreMemory = hasOlder;
          } catch (error, stackTrace) {
            if (!_isCurrentDataScope(generation)) return;
            // Keep visible records and allow an explicit load-more retry.
            logger.w(
              'Memory history availability check failed',
              error: error,
              stackTrace: stackTrace,
            );
          }
        }
        if (!_isCurrentDataScope(generation)) return;
      }

      // ✅ STOP UI card 不再觸發 weather
      if (isMemoryTrace) {
        _viewModelCache.retainEvents(loadedEvents);
      } else {
        _invalidateViewModelCache();
      }
    } catch (error, stackTrace) {
      if (!_isCurrentDataScope(generation)) return;
      _loadEventsError = error;
      logger.e(
        'loadEvents failed for $_tableName',
        error: error,
        stackTrace: stackTrace,
      );
    } finally {
      if (_isCurrentDataScope(generation)) {
        _isLoadingEvents = false;
        _isLoadingMemoryRecords = false;
        _isCheckingMoreMemory = false;
        notifyListeners();
      }
    }

    if (!_isCurrentDataScope(generation) || _loadEventsError != null) return;

    if (isGetPublicEvents &&
        !_disposed &&
        auth.isSysAdmin &&
        _tableName == TableNames.recommendEvents) {
      _beginPublicEventServiceOperation();
      try {
        await _serviceEventPublic.fetchAndSaveAllEvents();
        if (!_isCurrentDataScope(generation)) return;

        final newList = await _serviceEvent.getEvents(
          tableName: _tableName,
          inputUser: auth.currentAccount,
          storageLocation: auth.preferredStorage,
          limit: usesCloudPagination ? _cloudPageSize + 1 : null,
          shouldContinue: () => _isCurrentDataScope(generation),
        );
        if (!_isCurrentDataScope(generation)) return;
        var refreshedEvents = newList ?? [];
        if (usesCloudPagination) {
          refreshedEvents = _acceptCloudPage(refreshedEvents);
        }
        _modelEvent.setEvents(refreshedEvents);
        _hasLoadedEventsSuccessfully = true;
        _sortRecommendedContent();
        _invalidateViewModelCache();
        if (!_disposed) notifyListeners();
      } catch (error, stackTrace) {
        if (!_isCurrentDataScope(generation)) return;
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
    _handleAuthChange();
    if (_tableName != TableNames.memoryTrace ||
        _isLoadingEvents ||
        _isCheckingMoreMemory ||
        _isLoadingMoreMemory ||
        !_hasMoreMemory) {
      return;
    }
    if (_loadEventsError != null) {
      await loadEvents(isGetPublicEvents: false);
      return;
    }
    final generation = _dataScopeGeneration;
    final loadedStart =
        _memoryLoadedStartDate ??
        DateTimeFormatter.dateOnly(
          DateTime.now(),
        ).subtract(const Duration(days: 29));
    _isLoadingMoreMemory = true;
    if (!_disposed) notifyListeners();
    try {
      if (usesCloudPagination && _hasMoreEvents) {
        var nextPage =
            await _serviceEvent.getEvents(
              tableName: _tableName,
              inputUser: auth.currentAccount,
              storageLocation: auth.preferredStorage,
              dateS: loadedStart,
              dateE: _memoryLoadedEndDate,
              limit: _cloudPageSize + 1,
              offset: _nextCloudOffset,
              shouldContinue: () => _isCurrentDataScope(generation),
            ) ??
            [];
        if (!_isCurrentDataScope(generation)) return;
        nextPage = _acceptCloudPage(nextPage, offset: _nextCloudOffset);
        _modelEvent.appendMemoryEvents(nextPage);
        if (_hasMoreEvents) return;
      }
      final latestOlder = await _serviceEvent.latestEventDateBefore(
        tableName: _tableName,
        before: loadedStart,
        inputUser: auth.currentAccount,
        storageLocation: auth.preferredStorage,
      );
      if (!_isCurrentDataScope(generation)) return;
      if (latestOlder == null) {
        _hasMoreMemory = false;
        return;
      }
      final rangeEnd = DateTimeFormatter.dateOnly(latestOlder);
      final rangeStart = rangeEnd.subtract(const Duration(days: 29));
      final olderEvents =
          await _serviceEvent.getEvents(
            tableName: _tableName,
            inputUser: auth.currentAccount,
            storageLocation: auth.preferredStorage,
            dateS: rangeStart,
            dateE: rangeEnd,
            limit: usesCloudPagination ? _cloudPageSize + 1 : null,
            shouldContinue: () => _isCurrentDataScope(generation),
          ) ??
          [];
      if (!_isCurrentDataScope(generation)) return;
      var visibleOlderEvents = olderEvents;
      if (usesCloudPagination) {
        visibleOlderEvents = _acceptCloudPage(olderEvents);
      }
      _modelEvent.appendMemoryEvents(visibleOlderEvents);
      _memoryLoadedStartDate = rangeStart;
      _memoryLoadedEndDate = rangeEnd;
      _hasMoreMemory =
          _hasMoreEvents ||
          await _serviceEvent.hasEventsBefore(
            tableName: _tableName,
            before: rangeStart,
            inputUser: auth.currentAccount,
            storageLocation: auth.preferredStorage,
          );
    } finally {
      if (_isCurrentDataScope(generation)) {
        _isLoadingMoreMemory = false;
        notifyListeners();
      }
    }
  }

  Future<void> loadMoreRecommendedEvents() async {
    _handleAuthChange();
    if (!_isRecommendedContent ||
        !usesCloudPagination ||
        _isLoadingMoreEvents ||
        !_hasMoreEvents) {
      return;
    }
    final generation = _dataScopeGeneration;
    _isLoadingMoreEvents = true;
    if (!_disposed) notifyListeners();
    try {
      var nextPage =
          await _serviceEvent.getEvents(
            tableName: _tableName,
            inputUser: auth.currentAccount,
            storageLocation: auth.preferredStorage,
            limit: _cloudPageSize + 1,
            offset: _nextCloudOffset,
            shouldContinue: () => _isCurrentDataScope(generation),
          ) ??
          [];
      if (!_isCurrentDataScope(generation)) return;
      nextPage = _acceptCloudPage(nextPage, offset: _nextCloudOffset);
      _modelEvent.appendEvents(nextPage);
      _sortRecommendedContent();
      // Appending preserves existing event instances; their cached models
      // remain valid. Replaced rows, locale and permission changes are checked
      // by the cache, while full reloads still explicitly clear it.
    } finally {
      if (_isCurrentDataScope(generation)) {
        _isLoadingMoreEvents = false;
        notifyListeners();
      }
    }
  }

  void preloadWeatherForEvent(EventViewModel event) {
    if (_disposed || _dataScopeKey != _currentDataScopeKey) return;
    if (!_weatherPreloadAttemptedIds.add(event.id)) return;
    _pendingWeatherPreloads[event.id] = event;
    _weatherPreloadDebounce?.cancel();
    _weatherPreloadDebounce = Timer(
      const Duration(milliseconds: 80),
      _flushWeatherPreloads,
    );
  }

  void _flushWeatherPreloads() {
    if (_disposed || _pendingWeatherPreloads.isEmpty) return;
    final generation = _dataScopeGeneration;
    final events = _pendingWeatherPreloads.values.toList(growable: false);
    _pendingWeatherPreloads.clear();
    _weatherPreloadQueue = _weatherPreloadQueue
        .then((_) => _preloadWeatherForEvents(events, generation))
        .catchError((_) {});
  }

  Future<void> _preloadWeatherForEvents(
    List<EventViewModel> events,
    int generation,
  ) async {
    if (!_isCurrentDataScope(generation)) return;
    final requested = await _serviceWeather.preloadWeather(
      events,
      tableName: _tableName,
      shouldContinue: () => _isCurrentDataScope(generation),
    );
    if (requested && _isCurrentDataScope(generation)) notifyListeners();
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
    if (notifierDisposed) return;
    await tracking.openEventLink(
      eventId: event.id,
      eventName: event.name,
      url: event.masterUrl,
    );
  }

  Future<void> onOpenMap(EventViewModel event) async {
    if (notifierDisposed) return;
    await tracking.openEventMap(
      eventId: event.id,
      eventName: event.name,
      city: event.event.city,
      location: event.event.location,
    );
  }

  bool _isRefreshingPublicEvents = false;
  bool get isRefreshingPublicEvents => _isRefreshingPublicEvents;
  bool _publicEventsUpdatedToday = false;
  bool _publicEventsRefreshRunning = false;
  bool get publicEventsRefreshRunning => _publicEventsRefreshRunning;
  PublicEventRefreshSummary get lastPublicEventRefreshSummary =>
      _serviceEventPublic.lastRefreshSummary;
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
    final generation = _dataScopeGeneration;
    _beginPublicEventServiceOperation();
    try {
      final status = await _serviceEventPublic.getRefreshStatus();
      if (!_isCurrentDataScope(generation)) return;
      _publicEventsUpdatedToday = status.updated;
      _publicEventsRefreshRunning = status.running;
    } catch (error, stackTrace) {
      if (!_isCurrentDataScope(generation)) return;
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
    final generation = _dataScopeGeneration;
    _beginPublicEventServiceOperation();
    notifyListeners();
    try {
      final execution = await _serviceEventPublic.fetchAndSaveAllEvents();
      if (!_isCurrentDataScope(generation)) return false;
      if (execution == PublicEventRefreshExecution.running) {
        _publicEventsRefreshRunning = true;
        _hasCheckedPublicEventsUpdate = true;
        return false;
      }
      final newList = await _serviceEvent.getEvents(
        tableName: _tableName,
        inputUser: auth.currentAccount,
        storageLocation: auth.preferredStorage,
        limit: usesCloudPagination ? _cloudPageSize + 1 : null,
        shouldContinue: () => _isCurrentDataScope(generation),
      );
      if (!_isCurrentDataScope(generation)) return false;
      var refreshedEvents = newList ?? <EventItem>[];
      if (usesCloudPagination) {
        refreshedEvents = _acceptCloudPage(refreshedEvents);
      }
      _modelEvent.setEvents(refreshedEvents);
      _hasLoadedEventsSuccessfully = true;
      _loadEventsError = null;
      _sortRecommendedContent();
      _invalidateViewModelCache();
      notifyListeners();
      if (!_isCurrentDataScope(generation)) return false;
      final status = await _serviceEventPublic.getRefreshStatus();
      if (!_isCurrentDataScope(generation)) return false;
      _publicEventsUpdatedToday = status.updated;
      _publicEventsRefreshRunning = status.running;
      _hasCheckedPublicEventsUpdate = true;
      if (!_disposed) notifyListeners();
      return _publicEventsUpdatedToday;
    } catch (error, stackTrace) {
      if (!_isCurrentDataScope(generation)) return false;
      logger.e(
        'refreshPublicEvents failed',
        error: error,
        stackTrace: stackTrace,
      );
      // Keep the action available after a failed batch or a lost finalize
      // response. The server still prevents concurrent work and expires stale
      // locks after its configured timeout.
      _publicEventsUpdatedToday = false;
      _publicEventsRefreshRunning = false;
      _hasCheckedPublicEventsUpdate = true;
      return false;
    } finally {
      _endPublicEventServiceOperation();
      if (_isCurrentDataScope(generation)) {
        _isRefreshingPublicEvents = false;
        notifyListeners();
      }
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
    auth.removeListener(_handleAuthChange);
    _searchDebounce?.cancel();
    _weatherPreloadDebounce?.cancel();
    _pendingWeatherPreloads.clear();
    _closePublicEventServiceIfIdle();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}
