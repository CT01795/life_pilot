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

class ModelDashboard extends SafeChangeNotifier {
  final DashboardRepository repository;
  final ProviderLocale localeProvider;
  int _accountGeneration = 0;
  String? _activeAccount;
  Future<DashboardSetting>? _settingsLoad;
  int _settingsRequest = 0;

  ModelDashboard({required this.repository, required this.localeProvider});

  bool _loading = false;
  final Map<DashboardSection, int> _sectionLoadingCounts = {};
  final Set<DashboardSection> _failedSections = {};
  int _recommendEventRequest = 0;
  int _recommendPlaceRequest = 0;
  int _accountingRequest = 0;
  int _pointsRequest = 0;

  bool get loading => _loading;

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
    _activeAccount = account;
    _settingsLoad = null;
    _loading = false;
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
    final generation = _accountGeneration;
    final recommendEventRequest = ++_recommendEventRequest;
    final recommendPlaceRequest = ++_recommendPlaceRequest;
    final accountingRequest = ++_accountingRequest;
    final pointsRequest = ++_pointsRequest;
    if (!_isCurrentRequest(account, generation)) return;
    _loading = true;
    _beginLoading(sections);
    _failedSections.clear();
    notifyListeners();

    try {
      final todayEventsFuture =
          _loadSection(
            DashboardSection.todaySchedule,
            () => repository.loadTodayEvents(account),
          ).then((todayEvents) {
            if (_isCurrentRequest(account, generation) && todayEvents != null) {
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
            () => repository.loadRecommendEvents(setting.recommendEventCity),
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
            () => repository.loadRecommendPlaces(setting.recommendPlaceCity),
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
            () => repository.loadAccountingSummary(
              accountId: setting.accountingAccountId ?? '',
            ),
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
            () => repository.loadPointSummary(
              accountId: setting.pointAccountId ?? '',
            ),
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
        _loading = false;
        _endLoading(sections);
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
    final generation = _accountGeneration;
    final accountingRequest = ++_accountingRequest;
    final pointsRequest = ++_pointsRequest;
    if (!_isCurrentRequest(account, generation)) return;
    _loading = true;
    _beginLoading(sections);
    _failedSections.removeAll(sections);
    notifyListeners();

    try {
      final todayEventsFuture =
          _loadSection(
            DashboardSection.todaySchedule,
            () => repository.loadTodayEvents(account),
          ).then((todayEvents) {
            if (_isCurrentRequest(account, generation) && todayEvents != null) {
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
            () => repository.loadAccountingSummary(
              accountId: setting.accountingAccountId ?? '',
            ),
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
              () => repository.loadPointSummary(
                accountId: setting.pointAccountId ?? '',
              ),
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
        _loading = false;
        _endLoading(sections);
        notifyListeners();
      }
    }
  }

  Future<T?> _loadSection<T>(
    DashboardSection section,
    Future<T> Function() loader,
  ) async {
    try {
      return await loader();
    } catch (error, stackTrace) {
      logger.e(
        'Could not load dashboard section: $section.',
        error: error,
        stackTrace: stackTrace,
      );
      _failedSections.add(section);
      return null;
    }
  }

  Future<void> retrySection({
    required DashboardSection section,
    required String account,
  }) async {
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
      _failedSections.remove(section);
    } catch (error, stackTrace) {
      _failedSections.add(section);
      logger.e(
        'Could not retry dashboard section: $section.',
        error: error,
        stackTrace: stackTrace,
      );
    } finally {
      notifyListeners();
    }
  }

  Future<void> refreshTodaySchedule({required String account}) async {
    final generation = _accountGeneration;
    if (!_isCurrentRequest(account, generation)) return;
    _loading = true;
    _beginLoading(const [DashboardSection.todaySchedule]);
    notifyListeners();

    try {
      final todayEvents = await repository.loadTodayEvents(account);
      if (!_isCurrentRequest(account, generation)) return;

      _state = _state.copyWith(todayEvents: todayEvents);
    } finally {
      if (_isCurrentRequest(account, generation)) {
        _loading = false;
        _endLoading(const [DashboardSection.todaySchedule]);
        notifyListeners();
      }
    }
  }

  Future<void> refreshRecommendEvent({required String account}) async {
    final generation = _accountGeneration;
    if (!_isCurrentRequest(account, generation)) return;
    final request = ++_recommendEventRequest;
    _loading = true;
    _beginLoading(const [DashboardSection.recommendEvents]);
    notifyListeners();

    try {
      final recommendedEvents = await repository.loadRecommendEvents(
        _setting.recommendEventCity,
      );

      if (!_isCurrentRequest(account, generation) ||
          request != _recommendEventRequest) {
        return;
      }

      _state = _state.copyWith(recommendEvents: recommendedEvents);
    } finally {
      if (_isCurrentRequest(account, generation)) {
        _endLoading(const [DashboardSection.recommendEvents]);
      }
      if (_isCurrentRequest(account, generation) &&
          request == _recommendEventRequest) {
        _loading = false;
        notifyListeners();
      }
    }
  }

  Future<void> refreshRecommendPlace({required String account}) async {
    final generation = _accountGeneration;
    if (!_isCurrentRequest(account, generation)) return;
    final request = ++_recommendPlaceRequest;
    _loading = true;
    _beginLoading(const [DashboardSection.recommendPlaces]);
    notifyListeners();

    try {
      final recommendedPlaces = await repository.loadRecommendPlaces(
        _setting.recommendPlaceCity,
      );

      if (!_isCurrentRequest(account, generation) ||
          request != _recommendPlaceRequest) {
        return;
      }

      _state = _state.copyWith(recommendPlaces: recommendedPlaces);
    } finally {
      if (_isCurrentRequest(account, generation)) {
        _endLoading(const [DashboardSection.recommendPlaces]);
      }
      if (_isCurrentRequest(account, generation) &&
          request == _recommendPlaceRequest) {
        _loading = false;
        notifyListeners();
      }
    }
  }

  Future<void> refreshAccounting({required String accountId}) async {
    final account = _activeAccount;
    final generation = _accountGeneration;
    if (account == null || !_isCurrentRequest(account, generation)) return;
    final request = ++_accountingRequest;
    _loading = true;
    _beginLoading(const [DashboardSection.accounting]);
    notifyListeners();

    try {
      final summary = await repository.loadAccountingSummary(
        accountId: accountId,
      );

      if (!_isCurrentRequest(account, generation) ||
          request != _accountingRequest) {
        return;
      }

      _failedSections.remove(DashboardSection.accounting);
      _state = _state.copyWith(
        todayIncomeExpense: summary.records,
        accountingTotal: summary.total,
        todayAccountingTotal: summary.todayTotal,
        accountingCurrency: summary.currency,
      );
    } finally {
      if (_isCurrentRequest(account, generation)) {
        _endLoading(const [DashboardSection.accounting]);
      }
      if (_isCurrentRequest(account, generation) &&
          request == _accountingRequest) {
        _loading = false;
        notifyListeners();
      }
    }
  }

  Future<void> refreshPoints({required String accountId}) async {
    final account = _activeAccount;
    final generation = _accountGeneration;
    if (account == null || !_isCurrentRequest(account, generation)) return;
    final request = ++_pointsRequest;
    _loading = true;
    _beginLoading(const [DashboardSection.points]);
    notifyListeners();

    try {
      final summary = await repository.loadPointSummary(accountId: accountId);

      if (!_isCurrentRequest(account, generation) ||
          request != _pointsRequest) {
        return;
      }

      _failedSections.remove(DashboardSection.points);
      _state = _state.copyWith(
        todayPoints: summary.records,
        pointsTotal: summary.total,
        todayPointsTotal: summary.todayTotal,
      );
    } finally {
      if (_isCurrentRequest(account, generation)) {
        _endLoading(const [DashboardSection.points]);
      }
      if (_isCurrentRequest(account, generation) && request == _pointsRequest) {
        _loading = false;
        notifyListeners();
      }
    }
  }

  Future<void> completeEvent({
    required String id,
    required String account,
  }) async {
    final generation = _accountGeneration;
    if (!_isCurrentRequest(account, generation)) return;

    await repository.completeEvent(id: id, account: account);

    if (!_isCurrentRequest(account, generation)) return;
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
    if (_activeAccount != account) return;
    final events = ModelUpcomingSchedule.withEvent(
      events: _state.todayEvents,
      event: event,
      now: currentTime ?? DateTime.now(),
    );
    if (events == null) return;
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
