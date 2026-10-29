import 'dart:async';

import 'package:life_pilot/apps/config_app.dart';
import 'package:life_pilot/pages/home/model/dashboard/dashboard_city.dart';
import 'package:life_pilot/pages/home/model/dashboard/dashboard_setting.dart';
import 'package:life_pilot/pages/home/model/dashboard/model_upcoming_schedule.dart';
import 'package:life_pilot/pages/home/model/event/calendar_event.dart';
import 'package:life_pilot/utils/safe_change_notifier.dart';
import 'package:life_pilot/utils/refresh_request_coordinator.dart';
import 'package:life_pilot/pages/home/model/dashboard/dashboard_state.dart';
import 'package:life_pilot/pages/home/repository/repository_dashboard.dart';
import 'package:life_pilot/utils/provider_locale.dart';
import 'package:life_pilot/utils/logger.dart';

enum DashboardSection {
  todaySchedule,
  recommendEvents,
  recommendPlaces,
  accounting,
  points,
}

/// Coordinates dashboard requests and presentation state. Data structures live
/// in model/dashboard; persistence remains in DashboardRepository.
class ControllerDashboard extends SafeChangeNotifier {
  final DashboardRepository repository;
  final ProviderLocale localeProvider;
  int _accountGeneration = 0;
  String? _activeAccount;
  Future<DashboardSetting>? _settingsLoad;
  int _settingsRequest = 0;

  ControllerDashboard({required this.repository, required this.localeProvider});

  final Map<DashboardSection, int> _sectionLoadingCounts = {};
  final Map<DashboardSection, int> _retryRequests = {};
  final Set<DashboardSection> _failedSections = {};
  int _recommendEventRequest = 0;
  int _recommendPlaceRequest = 0;
  int _accountingRequest = 0;
  int _pointsRequest = 0;
  int _todayScheduleRequest = 0;
  final _eventCompletions = <(int, String), Future<void>>{};

  bool get loading => _sectionLoadingCounts.isNotEmpty;

  bool isLoading(DashboardSection section) =>
      (_sectionLoadingCounts[section] ?? 0) > 0;

  void _beginLoading(Iterable<DashboardSection> sections) {
    for (final section in sections) {
      _sectionLoadingCounts.update(
        section,
        (count) => count + 1,
        ifAbsent: () => 1,
      );
    }
  }

  void _endLoading(Iterable<DashboardSection> sections) {
    for (final section in sections) {
      final remaining = (_sectionLoadingCounts[section] ?? 1) - 1;
      if (remaining <= 0) {
        _sectionLoadingCounts.remove(section);
      } else {
        _sectionLoadingCounts[section] = remaining;
      }
    }
  }

  bool hasFailed(DashboardSection section) => _failedSections.contains(section);

  DashboardState _state = DashboardState.empty();
  DashboardState get state => _state;

  DashboardSetting _setting = DashboardSetting(
    recommendEventCity: '台北',
    recommendPlaceCity: '台北',
    language: Locales.zh,
  );

  DashboardSetting get setting => _setting;

  List<DashboardCity> _eventCities = [];
  bool _eventCitiesLoaded = false;
  RefreshRequestCoordinator _eventCityRequests = RefreshRequestCoordinator();

  List<DashboardCity> get eventCities => _eventCities;

  List<DashboardCity> _placeCities = [];
  bool _placeCitiesLoaded = false;
  RefreshRequestCoordinator _placeCityRequests = RefreshRequestCoordinator();

  List<DashboardCity> get placeCities => _placeCities;

  void switchAccount(String? account) {
    _accountGeneration++;
    _eventCompletions.clear();
    _activeAccount = account;
    _settingsLoad = null;
    _state = DashboardState.empty();
    _setting = DashboardSetting(
      recommendEventCity: '台北',
      recommendPlaceCity: '台北',
      language: localeProvider.locale.languageCode,
    );
    _eventCities = [];
    _placeCities = [];
    _eventCitiesLoaded = false;
    _placeCitiesLoaded = false;
    _eventCityRequests = RefreshRequestCoordinator();
    _placeCityRequests = RefreshRequestCoordinator();
    _sectionLoadingCounts.clear();
    _failedSections.clear();
    notifyListeners();
  }

  bool _isCurrentRequest(String account, int generation) =>
      !notifierDisposed &&
      _activeAccount == account &&
      _accountGeneration == generation;

  /// Recommendations need the saved city, not every dashboard summary.
  Future<void> waitForSettings({required String account}) async {
    final generation = _accountGeneration;
    while (_isCurrentRequest(account, generation)) {
      final pending = _settingsLoad;
      if (pending == null) return;
      await pending;
      if (identical(pending, _settingsLoad)) return;
    }
  }

  Future<DashboardSetting> _loadSettings(String account, int generation) =>
      _settingsLoad = _readSettings(account, generation, ++_settingsRequest);

  Future<DashboardSetting> _readSettings(
    String account,
    int generation,
    int request,
  ) async {
    var setting = _setting;
    try {
      final loaded = await repository.loadDashboardSetting(account: account);
      setting = loaded.copyWith(language: localeProvider.locale.languageCode);
    } catch (error, stackTrace) {
      logger.e(
        'Could not load dashboard settings.',
        error: error,
        stackTrace: stackTrace,
      );
    }
    if (_isCurrentRequest(account, generation) && request == _settingsRequest) {
      _setting = setting;
      notifyListeners();
    }
    return setting;
  }

  Future<void> loadEventCities(
    String account, {
    bool forceRefresh = false,
  }) async {
    final generation = _accountGeneration;
    if (!_isCurrentRequest(account, generation)) return;
    if (_eventCitiesLoaded && !forceRefresh && !_eventCityRequests.isRunning) {
      return;
    }
    await _eventCityRequests.run(
      () => _loadEventCities(account, generation),
      force: forceRefresh,
    );
  }

  Future<void> _loadEventCities(String account, int generation) async {
    if (!_isCurrentRequest(account, generation)) return;
    List<DashboardCity> eventCities;
    try {
      eventCities = await repository.loadEventCities();
    } catch (error, stackTrace) {
      logger.e(
        'Could not load recommended event cities.',
        error: error,
        stackTrace: stackTrace,
      );
      return;
    }
    if (!_isCurrentRequest(account, generation)) return;
    _eventCities = eventCities;
    _eventCitiesLoaded = true;
    notifyListeners();
  }

  Future<void> loadPlaceCities(
    String account, {
    bool forceRefresh = false,
  }) async {
    final generation = _accountGeneration;
    if (!_isCurrentRequest(account, generation)) return;
    if (_placeCitiesLoaded && !forceRefresh && !_placeCityRequests.isRunning) {
      return;
    }
    await _placeCityRequests.run(
      () => _loadPlaceCities(account, generation),
      force: forceRefresh,
    );
  }

  Future<void> _loadPlaceCities(String account, int generation) async {
    if (!_isCurrentRequest(account, generation)) return;
    List<DashboardCity> placeCities;
    try {
      placeCities = await repository.loadPlaceCities();
    } catch (error, stackTrace) {
      logger.e(
        'Could not load recommended place cities.',
        error: error,
        stackTrace: stackTrace,
      );
      return;
    }
    if (!_isCurrentRequest(account, generation)) return;
    _placeCities = placeCities;
    _placeCitiesLoaded = true;
    notifyListeners();
  }

  Future<void> refreshAll({required String account}) async {
    const sections = DashboardSection.values;
    final pendingSections = sections.toSet();
    final generation = _accountGeneration;
    if (!_isCurrentRequest(account, generation)) return;
    final scheduleRequest = ++_todayScheduleRequest;
    final recommendEventRequest = ++_recommendEventRequest;
    final recommendPlaceRequest = ++_recommendPlaceRequest;
    final accountingRequest = ++_accountingRequest;
    final pointsRequest = ++_pointsRequest;
    _beginLoading(sections);
    _failedSections.clear();
    notifyListeners();

    try {
      final todayEventsFuture =
          _loadSection(
            DashboardSection.todaySchedule,
            scheduleRequest,
            () => repository.loadTodayEvents(account),
            pendingSections: pendingSections,
          ).then((todayEvents) {
            if (_isCurrentRequest(account, generation) &&
                scheduleRequest == _todayScheduleRequest &&
                todayEvents != null) {
              _state = _state.copyWith(todayEvents: todayEvents);
              notifyListeners();
            }
            return todayEvents;
          });
      final setting = await _loadSettings(account, generation);
      if (!_isCurrentRequest(account, generation)) return;

      final recommendEventsFuture =
          _loadSection(
            DashboardSection.recommendEvents,
            recommendEventRequest,
            () => repository.loadRecommendEvents(setting.recommendEventCity),
            pendingSections: pendingSections,
          ).then((events) {
            if (!_isCurrentRequest(account, generation)) return;
            if (recommendEventRequest == _recommendEventRequest &&
                events != null) {
              _state = _state.copyWith(recommendEvents: events);
            }
            notifyListeners();
          });
      final recommendPlacesFuture =
          _loadSection(
            DashboardSection.recommendPlaces,
            recommendPlaceRequest,
            () => repository.loadRecommendPlaces(setting.recommendPlaceCity),
            pendingSections: pendingSections,
          ).then((places) {
            if (!_isCurrentRequest(account, generation)) return;
            if (recommendPlaceRequest == _recommendPlaceRequest &&
                places != null) {
              _state = _state.copyWith(recommendPlaces: places);
            }
            notifyListeners();
          });
      final accountingFuture =
          _loadSection(
            DashboardSection.accounting,
            accountingRequest,
            () => repository.loadAccountingSummary(
              accountId: setting.accountingAccountId ?? '',
            ),
            pendingSections: pendingSections,
          ).then((accounting) {
            if (!_isCurrentRequest(account, generation)) return;
            if (accountingRequest == _accountingRequest && accounting != null) {
              _state = _state.copyWith(
                todayIncomeExpense: accounting.records,
                accountingTotal: accounting.total,
                todayAccountingTotal: accounting.todayTotal,
                accountingCurrency: accounting.currency,
              );
            }
            notifyListeners();
          });
      final pointsFuture =
          _loadSection(
            DashboardSection.points,
            pointsRequest,
            () => repository.loadPointSummary(
              accountId: setting.pointAccountId ?? '',
            ),
            pendingSections: pendingSections,
          ).then((points) {
            if (!_isCurrentRequest(account, generation)) return;
            if (pointsRequest == _pointsRequest && points != null) {
              _state = _state.copyWith(
                todayPoints: points.records,
                pointsTotal: points.total,
                todayPointsTotal: points.todayTotal,
              );
            }
            notifyListeners();
          });

      await Future.wait([
        todayEventsFuture,
        recommendEventsFuture,
        recommendPlacesFuture,
        accountingFuture,
        pointsFuture,
      ]);
    } finally {
      if (_isCurrentRequest(account, generation)) {
        _endLoading(pendingSections);
        notifyListeners();
      }
    }
  }

  Future<void> refreshCore({
    required String account,
    bool includePoints = true,
  }) async {
    final sections = [
      DashboardSection.todaySchedule,
      DashboardSection.accounting,
      if (includePoints) DashboardSection.points,
    ];
    final pendingSections = sections.toSet();
    final generation = _accountGeneration;
    if (!_isCurrentRequest(account, generation)) return;
    final scheduleRequest = ++_todayScheduleRequest;
    final accountingRequest = ++_accountingRequest;
    final pointsRequest = ++_pointsRequest;
    _beginLoading(sections);
    _failedSections.removeAll(sections);
    notifyListeners();

    try {
      final todayEventsFuture =
          _loadSection(
            DashboardSection.todaySchedule,
            scheduleRequest,
            () => repository.loadTodayEvents(account),
            pendingSections: pendingSections,
          ).then((todayEvents) {
            if (_isCurrentRequest(account, generation) &&
                scheduleRequest == _todayScheduleRequest &&
                todayEvents != null) {
              _state = _state.copyWith(todayEvents: todayEvents);
              notifyListeners();
            }
            return todayEvents;
          });
      final setting = await _loadSettings(account, generation);
      if (!_isCurrentRequest(account, generation)) return;

      final accountingFuture =
          _loadSection(
            DashboardSection.accounting,
            accountingRequest,
            () => repository.loadAccountingSummary(
              accountId: setting.accountingAccountId ?? '',
            ),
            pendingSections: pendingSections,
          ).then((accounting) {
            if (_isCurrentRequest(account, generation) &&
                accountingRequest == _accountingRequest &&
                accounting != null) {
              _state = _state.copyWith(
                todayIncomeExpense: accounting.records,
                accountingTotal: accounting.total,
                todayAccountingTotal: accounting.todayTotal,
                accountingCurrency: accounting.currency,
              );
              notifyListeners();
            }
          });
      final pointsFuture = includePoints
          ? _loadSection(
              DashboardSection.points,
              pointsRequest,
              () => repository.loadPointSummary(
                accountId: setting.pointAccountId ?? '',
              ),
              pendingSections: pendingSections,
            ).then((points) {
              if (_isCurrentRequest(account, generation) &&
                  pointsRequest == _pointsRequest &&
                  points != null) {
                _state = _state.copyWith(
                  todayPoints: points.records,
                  pointsTotal: points.total,
                  todayPointsTotal: points.todayTotal,
                );
                notifyListeners();
              }
            })
          : Future<void>.value();
      await Future.wait([todayEventsFuture, accountingFuture, pointsFuture]);
    } finally {
      if (_isCurrentRequest(account, generation)) {
        _endLoading(pendingSections);
        notifyListeners();
      }
    }
  }

  int _sectionRequest(DashboardSection section) => switch (section) {
    DashboardSection.todaySchedule => _todayScheduleRequest,
    DashboardSection.recommendEvents => _recommendEventRequest,
    DashboardSection.recommendPlaces => _recommendPlaceRequest,
    DashboardSection.accounting => _accountingRequest,
    DashboardSection.points => _pointsRequest,
  };

  Future<T?> _loadSection<T>(
    DashboardSection section,
    int request,
    Future<T> Function() loader, {
    required Set<DashboardSection> pendingSections,
  }) async {
    final generation = _accountGeneration;
    final account = _activeAccount;
    bool isCurrent() =>
        account != null &&
        _isCurrentRequest(account, generation) &&
        request == _sectionRequest(section);
    // A settings read may have outlived the refresh that requested it.
    // Do not start superseded section reads or publish their late failures.
    if (!isCurrent()) return null;
    try {
      return await loader();
    } catch (error, stackTrace) {
      if (!isCurrent()) return null;
      logger.e(
        'Could not load dashboard section: $section.',
        error: error,
        stackTrace: stackTrace,
      );
      _failedSections.add(section);
      return null;
    } finally {
      // Each batch owns one loading count per section. Release it as soon as
      // that section settles, without consuming a concurrent refresh's count.
      if (account != null &&
          _isCurrentRequest(account, generation) &&
          pendingSections.remove(section)) {
        _endLoading([section]);
        notifyListeners();
      }
    }
  }

  Future<void> retrySection({
    required DashboardSection section,
    required String account,
  }) async {
    final generation = _accountGeneration;
    if (!_isCurrentRequest(account, generation)) return;
    final request = (_retryRequests[section] ?? 0) + 1;
    _retryRequests[section] = request;
    bool isCurrent() =>
        _isCurrentRequest(account, generation) &&
        _retryRequests[section] == request;
    try {
      switch (section) {
        case DashboardSection.todaySchedule:
          await refreshTodaySchedule(account: account);
        case DashboardSection.recommendEvents:
          await refreshRecommendEvent(account: account);
        case DashboardSection.recommendPlaces:
          await refreshRecommendPlace(account: account);
        case DashboardSection.accounting:
          final accountId = _setting.accountingAccountId;
          if (accountId == null) return;
          await refreshAccounting(accountId: accountId);
        case DashboardSection.points:
          final accountId = _setting.pointAccountId;
          if (accountId == null) return;
          await refreshPoints(accountId: accountId);
      }
      if (isCurrent()) _failedSections.remove(section);
    } catch (error, stackTrace) {
      if (!isCurrent()) return;
      _failedSections.add(section);
      logger.e(
        'Could not retry dashboard section: $section.',
        error: error,
        stackTrace: stackTrace,
      );
    } finally {
      if (isCurrent()) notifyListeners();
    }
  }

  /// Shared lifecycle for independent dashboard sections. Persistence stays in
  /// Repository; this controller publishes only the current account/request.
  Future<void> _refreshSection<T>({
    required DashboardSection section,
    required String? account,
    required int Function() advance,
    required bool Function(int) isLatest,
    required Future<T> Function() read,
    required void Function(T) apply,
  }) async {
    final generation = _accountGeneration;
    if (account == null || !_isCurrentRequest(account, generation)) return;
    final request = advance();
    bool active() =>
        _isCurrentRequest(account, generation) && isLatest(request);
    _beginLoading([section]);
    notifyListeners();
    try {
      // Listeners may synchronously switch accounts or supersede this read.
      if (!active()) return;
      final result = await read();
      if (active()) apply(result);
    } finally {
      if (_isCurrentRequest(account, generation)) {
        _endLoading([section]);
        notifyListeners();
      }
    }
  }

  Future<void> refreshTodaySchedule({required String account}) =>
      _refreshSection(
        section: DashboardSection.todaySchedule,
        account: account,
        advance: () => ++_todayScheduleRequest,
        isLatest: (request) => request == _todayScheduleRequest,
        read: () => repository.loadTodayEvents(account),
        apply: (events) => _state = _state.copyWith(todayEvents: events),
      );

  Future<void> refreshRecommendEvent({required String account}) =>
      _refreshSection(
        section: DashboardSection.recommendEvents,
        account: account,
        advance: () => ++_recommendEventRequest,
        isLatest: (request) => request == _recommendEventRequest,
        read: () => repository.loadRecommendEvents(_setting.recommendEventCity),
        apply: (events) => _state = _state.copyWith(recommendEvents: events),
      );

  Future<void> refreshRecommendPlace({required String account}) =>
      _refreshSection(
        section: DashboardSection.recommendPlaces,
        account: account,
        advance: () => ++_recommendPlaceRequest,
        isLatest: (request) => request == _recommendPlaceRequest,
        read: () => repository.loadRecommendPlaces(_setting.recommendPlaceCity),
        apply: (places) => _state = _state.copyWith(recommendPlaces: places),
      );

  Future<void> refreshAccounting({required String accountId}) =>
      _refreshSection(
        section: DashboardSection.accounting,
        account: _activeAccount,
        advance: () => ++_accountingRequest,
        isLatest: (request) => request == _accountingRequest,
        read: () => repository.loadAccountingSummary(accountId: accountId),
        apply: (summary) {
          _failedSections.remove(DashboardSection.accounting);
          _state = _state.copyWith(
            todayIncomeExpense: summary.records,
            accountingTotal: summary.total,
            todayAccountingTotal: summary.todayTotal,
            accountingCurrency: summary.currency,
          );
        },
      );

  Future<void> refreshPoints({required String accountId}) => _refreshSection(
    section: DashboardSection.points,
    account: _activeAccount,
    advance: () => ++_pointsRequest,
    isLatest: (request) => request == _pointsRequest,
    read: () => repository.loadPointSummary(accountId: accountId),
    apply: (summary) {
      _failedSections.remove(DashboardSection.points);
      _state = _state.copyWith(
        todayPoints: summary.records,
        pointsTotal: summary.total,
        todayPointsTotal: summary.todayTotal,
      );
    },
  );

  Future<void> completeEvent({required String id, required String account}) {
    final generation = _accountGeneration;
    if (!_isCurrentRequest(account, generation)) return Future.value();
    final key = (generation, id);
    final active = _eventCompletions[key];
    if (active != null) return active;
    final completion = Completer<void>();
    final request = completion.future;
    // Register before persistence: synchronous callbacks share the same write.
    _eventCompletions[key] = request;
    void release() {
      if (identical(_eventCompletions[key], request)) {
        _eventCompletions.remove(key);
      }
    }

    unawaited(
      _completeEvent(id, account, generation).then<void>(
        (_) {
          release();
          completion.complete();
        },
        onError: (Object error, StackTrace stack) {
          release();
          completion.completeError(error, stack);
        },
      ),
    );
    return request;
  }

  Future<void> _completeEvent(String id, String account, int generation) async {
    await repository.completeEvent(id: id, account: account);

    if (!_isCurrentRequest(account, generation)) return;
    _todayScheduleRequest++;
    _state = _state.copyWith(
      todayEvents: _state.todayEvents
          .where((event) => event.id != id)
          .toList(growable: false),
    );
    notifyListeners();
  }

  void addUpcomingEvent(
    CalendarEvent event, {
    required String account,
    DateTime? currentTime,
  }) {
    if (notifierDisposed || _activeAccount != account) return;
    final events = ModelUpcomingSchedule.withEvent(
      events: _state.todayEvents,
      event: event,
      now: currentTime ?? DateTime.now(),
    );
    if (events == null) return;
    _todayScheduleRequest++;
    _state = _state.copyWith(todayEvents: events);
    notifyListeners();
  }

  /// Keeps settings writes scoped to the account and lifecycle that started
  /// them. Repository owns persistence; stale completions must not publish or
  /// launch another dashboard refresh.
  Future<bool> _saveSetting({
    required String account,
    required DashboardSetting setting,
    bool publishBeforeSave = false,
  }) async {
    final generation = _accountGeneration;
    if (!_isCurrentRequest(account, generation)) return false;
    if (publishBeforeSave) _setting = setting;
    await repository.saveDashboardSetting(account: account, setting: setting);
    if (!_isCurrentRequest(account, generation)) return false;
    if (!publishBeforeSave) {
      _setting = setting;
      notifyListeners();
    }
    // A listener can synchronously switch accounts during publication.
    return _isCurrentRequest(account, generation);
  }

  Future<void> changeEventCity({
    required String account,
    required String city,
  }) async {
    final updatedSetting = _setting.copyWith(recommendEventCity: city);

    if (!await _saveSetting(account: account, setting: updatedSetting)) {
      return;
    }

    await refreshRecommendEvent(account: account);
  }

  Future<void> changePlaceCity({
    required String account,
    required String city,
  }) async {
    final updatedSetting = _setting.copyWith(recommendPlaceCity: city);

    if (!await _saveSetting(account: account, setting: updatedSetting)) {
      return;
    }

    await refreshRecommendPlace(account: account);
  }

  Future<void> changeLanguage({
    required String account,
    required String language,
  }) async {
    if (!await _saveSetting(
      account: account,
      setting: _setting.copyWith(language: language),
      publishBeforeSave: true,
    )) {
      return;
    }

    await refreshAll(account: account);
  }

  Future<void> changeAccountingAccount({
    required String account,
    required String? accountId,
    required String? accountName,
  }) async {
    final updatedSetting = _setting.copyWith(
      accountingAccountId: accountId,
      accountingAccountName: accountName,
    );

    if (!await _saveSetting(account: account, setting: updatedSetting)) {
      return;
    }

    if (accountId == null) {
      _accountingRequest++;
      _failedSections.remove(DashboardSection.accounting);
      _state = _state.copyWith(
        todayIncomeExpense: const [],
        accountingTotal: 0,
        todayAccountingTotal: 0,
        accountingCurrency: 'TWD',
      );
      notifyListeners();
    } else {
      _failedSections.remove(DashboardSection.accounting);
      _state = _state.copyWith(
        todayIncomeExpense: const [],
        accountingTotal: 0,
        todayAccountingTotal: 0,
      );
      notifyListeners();
      await refreshAccounting(accountId: accountId);
    }
  }

  Future<void> changePointAccount({
    required String account,
    required String? accountId,
    required String? accountName,
  }) async {
    final updatedSetting = _setting.copyWith(
      pointAccountId: accountId,
      pointAccountName: accountName,
    );

    if (!await _saveSetting(account: account, setting: updatedSetting)) {
      return;
    }

    if (accountId == null) {
      _pointsRequest++;
      _failedSections.remove(DashboardSection.points);
      _state = _state.copyWith(
        todayPoints: const [],
        pointsTotal: 0,
        todayPointsTotal: 0,
      );
      notifyListeners();
    } else {
      _failedSections.remove(DashboardSection.points);
      _state = _state.copyWith(
        todayPoints: const [],
        pointsTotal: 0,
        todayPointsTotal: 0,
      );
      notifyListeners();
      await refreshPoints(accountId: accountId);
    }
  }
}
