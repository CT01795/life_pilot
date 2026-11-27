import 'dart:async';
import 'package:life_pilot/accounting/service_ledger_sharing.dart';

import 'package:life_pilot/apps/config_app.dart';
import 'package:life_pilot/pages/home/model/dashboard/dashboard_bootstrap.dart';
import 'package:life_pilot/pages/home/model/dashboard/dashboard_city.dart';
import 'package:life_pilot/pages/home/model/dashboard/dashboard_setting.dart';
import 'package:life_pilot/pages/home/model/dashboard/model_upcoming_schedule.dart';
import 'package:life_pilot/pages/home/model/event/calendar_event.dart';
import 'package:life_pilot/pages/home/model/event/recommended_event.dart';
import 'package:life_pilot/pages/home/model/place/recommended_place.dart';
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
  Future<DashboardBootstrap>? _settingsLoad;
  int _settingsRequest = 0;
  Future<void>? _settingsSaveTail;

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
  final _eventDetails = <String, Future<CalendarEvent>>{};

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

  final _sharedLedgers = <bool, ({String id, String name})>{};
  final _sharedSummaries = <bool, Future<SharedLedgerHomeSnapshot>>{};
  final _sharedReads = <bool, RefreshRequestCoordinator>{};
  final _sharedReadRevisions = <bool, int>{};
  final _sharedToday = <bool, Map<String, dynamic>>{};
  Map<String, dynamic>? sharedToday({required bool points}) =>
      _sharedToday[points];
  final _sharing = ServiceLedgerSharing();
  bool _sharedRestored = false;
  bool _includeCloudShares = true;
  Future<void>? _sharedRestore;
  int _sharedSelectionRevision = 0;

  Future<SharedLedgerHomeSnapshot>? sharedSummary({required bool points}) =>
      _sharedSummaries[points];

  Future<void> refreshSharedSummary({required bool points, bool force = true}) {
    final id = _sharedLedgers[points]?.id;
    if (id == null || notifierDisposed) return Future<void>.value();
    final loads = _sharedReads.putIfAbsent(
      points,
      RefreshRequestCoordinator.new,
    );
    if (force) {
      _sharedReadRevisions.update(
        points,
        (value) => value + 1,
        ifAbsent: () => 1,
      );
    }
    return loads.run(() async {
      if (notifierDisposed ||
          !identical(_sharedReads[points], loads) ||
          _sharedLedgers[points]?.id != id) {
        return;
      }
      await _readSharedSummary(points, id, force: force);
    }, force: force);
  }

  Future<void> _readSharedSummary(
    bool points,
    String id, {
    required bool force,
  }) async {
    final revision = _sharedReadRevisions[points];
    final future = Future<SharedLedgerHomeSnapshot>.sync(
      () => _sharing.homePreview(id, force: force),
    );
    _sharedSummaries[points] = future;
    bool current() =>
        !notifierDisposed &&
        revision == _sharedReadRevisions[points] &&
        identical(_sharedSummaries[points], future);
    notifyListeners();
    try {
      final snapshot = await future;
      if (current()) _sharedToday[points] = snapshot.totals;
    } catch (_) {
      if (current()) _sharedToday.remove(points);
    }
    if (current()) notifyListeners();
  }

  ({String id, String name})? sharedLedger({required bool points}) =>
      _sharedLedgers[points];

  Future<void> selectSharedLedger({
    required bool points,
    required ({String id, String name})? selection,
  }) async {
    if (!_includeCloudShares) return;
    final account = _activeAccount;
    if (account == null) return;
    final generation = _accountGeneration;
    await _sharedRestore;
    if (!_isCurrentRequest(account, generation) ||
        _sharedLedgers[points] == selection) {
      return;
    }
    final previous = _sharedLedgers[points];
    ++_sharedSelectionRevision;
    final id = selection?.id ?? previous?.id;
    if (id != null) await _sharing.setHomeLink(id, selection != null);
    if (!_isCurrentRequest(account, generation)) return;
    _sharedReads.remove(points);
    _sharedReadRevisions.remove(points);
    _sharedToday.remove(points);
    if (selection == null) {
      _sharedLedgers.remove(points);
      _sharedSummaries.remove(points);
      notifyListeners();
    } else {
      _sharedLedgers[points] = selection;
      unawaited(refreshSharedSummary(points: points, force: false));
    }
  }

  Future<void> _restoreSharedLedgers(
    String account,
    int generation,
    List<Map<String, dynamic>> links,
  ) async {
    if (!_includeCloudShares || _sharedRestored) return;
    _sharedRestored = true;
    final revision = _sharedSelectionRevision;
    try {
      if (!_isCurrentRequest(account, generation) ||
          revision != _sharedSelectionRevision) {
        return;
      }
      for (final row in links) {
        final id = row['share_id'];
        final kind = row['kind'];
        if (id is! String || (kind != 'accounting' && kind != 'points')) {
          continue;
        }
        final points = kind == 'points';
        _sharedLedgers[points] = (
          id: id,
          name: row['account_name']?.toString() ?? '',
        );
        _applySharedSnapshot(points, row);
      }
      notifyListeners();
    } catch (_) {
      if (_isCurrentRequest(account, generation)) _sharedRestored = false;
    }
  }

  void _applySharedSnapshot(bool points, Map<String, dynamic> row) {
    final raw = row['snapshot'];
    if (raw is! Map || raw['totals'] is! Map || raw['entries'] is! List) {
      throw const FormatException('Invalid shared ledger bootstrap');
    }
    final snapshot = (
      totals: Map<String, dynamic>.unmodifiable(raw['totals'] as Map),
      entries: List<Map<String, dynamic>>.unmodifiable(
        (raw['entries'] as List).map(
          (entry) => Map<String, dynamic>.unmodifiable(entry as Map),
        ),
      ),
    );
    _sharedReads.remove(points);
    _sharedSummaries[points] = Future.value(snapshot);
    _sharedToday[points] = snapshot.totals;
  }

  List<DashboardCity> _eventCities = [];
  bool _eventCitiesLoaded = false;

  List<DashboardCity> get eventCities => _eventCities;

  List<DashboardCity> _placeCities = [];
  bool _placeCitiesLoaded = false;
  RefreshRequestCoordinator _allCityRequests = RefreshRequestCoordinator();

  List<DashboardCity> get placeCities => _placeCities;

  void switchAccount(String? account, {bool includeCloudShares = true}) {
    _includeCloudShares = includeCloudShares;
    _sharedLedgers.clear();
    _sharedSummaries.clear();
    _sharedReads.clear();
    _sharedReadRevisions.clear();
    _sharedToday.clear();
    _sharedRestored = false;
    _sharedRestore = null;
    _sharedSelectionRevision++;
    _accountGeneration++;
    _eventCompletions.clear();
    _eventDetails.clear();
    _activeAccount = account;
    _settingsLoad = null;
    _settingsSaveTail = null;
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
    _allCityRequests = RefreshRequestCoordinator();
    _sectionLoadingCounts.clear();
    _failedSections.clear();
    notifyListeners();
  }

  bool _isCurrentRequest(String account, int generation) =>
      !notifierDisposed &&
      _activeAccount == account &&
      _accountGeneration == generation;

  Future<CalendarEvent> loadCalendarEventDetail({
    required CalendarEvent summary,
    required String account,
  }) {
    final existing = _eventDetails[summary.id];
    if (existing != null) return existing;
    late final Future<CalendarEvent> request;
    request = repository
        .loadCalendarEventDetail(summary: summary, account: account)
        .whenComplete(() {
          if (identical(_eventDetails[summary.id], request)) {
            _eventDetails.remove(summary.id);
          }
        });
    _eventDetails[summary.id] = request;
    return request;
  }

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

  Future<DashboardBootstrap> _loadSettings(String account, int generation) {
    final completion = Completer<DashboardBootstrap>();
    final request = completion.future;
    // Publish before repository callbacks can start a newer account/refresh.
    _settingsLoad = request;
    unawaited(
      _readSettings(account, generation, ++_settingsRequest).then<void>(
        (setting) => completion.complete(setting),
        onError: (Object error, StackTrace stack) =>
            completion.completeError(error, stack),
      ),
    );
    return request;
  }

  Future<DashboardBootstrap> _readSettings(
    String account,
    int generation,
    int request,
  ) async {
    var bootstrap = DashboardBootstrap(setting: _setting);
    try {
      if (!_isCurrentRequest(account, generation)) return bootstrap;
      bootstrap = await repository.loadDashboardBootstrap(account: account);
    } catch (error, stackTrace) {
      logger.e(
        'Could not load dashboard settings.',
        error: error,
        stackTrace: stackTrace,
      );
    }
    if (!_isCurrentRequest(account, generation) ||
        request != _settingsRequest) {
      return DashboardBootstrap(setting: _setting);
    }
    _setting = bootstrap.setting.copyWith(
      language: localeProvider.locale.languageCode,
    );
    if (_includeCloudShares &&
        !_sharedRestored &&
        bootstrap.sharedLedgers != null) {
      _sharedRestore = _restoreSharedLedgers(
        account,
        generation,
        bootstrap.sharedLedgers!,
      );
    }
    notifyListeners();
    return bootstrap;
  }

  Future<void> loadRecommendationCities(
    String account, {
    bool forceRefresh = false,
  }) async {
    final generation = _accountGeneration;
    if (!_isCurrentRequest(account, generation)) return;
    if (_eventCitiesLoaded &&
        _placeCitiesLoaded &&
        !forceRefresh &&
        !_allCityRequests.isRunning) {
      return;
    }
    if (forceRefresh) repository.invalidateRecommendationCityCounts();
    await _allCityRequests.run(() async {
      if (!_isCurrentRequest(account, generation)) return;
      try {
        final cities = await repository.loadRecommendationCityCounts();
        if (!_isCurrentRequest(account, generation)) return;
        _eventCities = cities.events;
        _placeCities = cities.places;
        _eventCitiesLoaded = true;
        _placeCitiesLoaded = true;
        notifyListeners();
      } catch (error, stackTrace) {
        logger.e(
          'Could not load recommendation cities.',
          error: error,
          stackTrace: stackTrace,
        );
      }
    }, force: forceRefresh);
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
      if (!_isCurrentRequest(account, generation)) return;
      final bootstrap = await _loadSettings(account, generation);
      final setting = bootstrap.setting;
      if (!_isCurrentRequest(account, generation)) return;

      final todayEventsFuture =
          _loadSection(
            DashboardSection.todaySchedule,
            scheduleRequest,
            () async =>
                bootstrap.todayEvents ??
                await repository.loadTodayEvents(account),
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

      Future<({List<RecommendedEvent> events, List<RecommendedPlace> places})>?
      recommendationRead;
      Future<({List<RecommendedEvent> events, List<RecommendedPlace> places})>
      recommendations() =>
          recommendationRead ??= repository.loadRecommendations(
            eventCity: setting.recommendEventCity,
            placeCity: setting.recommendPlaceCity,
          );

      final recommendEventsFuture =
          _loadSection(
            DashboardSection.recommendEvents,
            recommendEventRequest,
            () async => (await recommendations()).events,
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
            () async => (await recommendations()).places,
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
            () async =>
                bootstrap.accounting ??
                await repository.loadAccountingSummary(
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
            () async =>
                bootstrap.points ??
                await repository.loadPointSummary(
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
    bool refreshShared = false,
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
    final sharedAtStart = refreshShared ? Map.of(_sharedSummaries) : null;
    final sharedRevisions = refreshShared ? Map.of(_sharedReadRevisions) : null;
    final selectionRevision = _sharedSelectionRevision;
    _beginLoading(sections);
    _failedSections.removeAll(sections);
    notifyListeners();

    try {
      if (!_isCurrentRequest(account, generation)) return;
      final bootstrap = await _loadSettings(account, generation);
      final setting = bootstrap.setting;
      if (!_isCurrentRequest(account, generation)) return;

      final sharedFuture =
          sharedAtStart != null &&
              scheduleRequest == _todayScheduleRequest &&
              selectionRevision == _sharedSelectionRevision
          ? _refreshSelectedSharedLedgers(
              bootstrap.sharedLedgers,
              sharedAtStart,
              sharedRevisions!,
              includePoints: includePoints,
            )
          : Future<void>.value();
      final todayEventsFuture =
          _loadSection(
            DashboardSection.todaySchedule,
            scheduleRequest,
            () async =>
                bootstrap.todayEvents ??
                await repository.loadTodayEvents(account),
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

      final accountingFuture =
          _loadSection(
            DashboardSection.accounting,
            accountingRequest,
            () async =>
                bootstrap.accounting ??
                await repository.loadAccountingSummary(
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
              () async =>
                  bootstrap.points ??
                  await repository.loadPointSummary(
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
      await Future.wait([
        todayEventsFuture,
        accountingFuture,
        pointsFuture,
        sharedFuture,
      ]);
    } finally {
      if (_isCurrentRequest(account, generation)) {
        _endLoading(pendingSections);
        notifyListeners();
      }
    }
  }

  Future<void> _refreshSelectedSharedLedgers(
    List<Map<String, dynamic>>? links,
    Map<bool, Future<SharedLedgerHomeSnapshot>> previous,
    Map<bool, int> previousRevisions, {
    required bool includePoints,
  }) async {
    final pending = <Future<void>>[];
    for (final points in [false, if (includePoints) true]) {
      final id = _sharedLedgers[points]?.id;
      if (id == null ||
          !identical(previous[points], _sharedSummaries[points]) ||
          previousRevisions[points] != _sharedReadRevisions[points]) {
        continue;
      }
      final row = links?.where((row) => row['share_id'] == id).firstOrNull;
      if (row != null) {
        try {
          _applySharedSnapshot(points, row);
          continue;
        } on FormatException catch (error) {
          logger.w('Invalid shared ledger snapshot', error: error);
        }
      }
      pending.add(refreshSharedSummary(points: points));
    }
    await Future.wait(pending);
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
    } catch (_) {
      // A replaced section or account cannot report errors on the new screen.
      // Current failures still reach the View/retry action as before.
      if (active()) rethrow;
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
    if (_state.todayEvents.any((event) => event.id == id && event.isShared)) {
      return Future.error(StateError('Shared calendar events are read-only'));
    }
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
    required DashboardSetting Function(DashboardSetting current) update,
  }) async {
    final generation = _accountGeneration;
    if (!_isCurrentRequest(account, generation)) return false;
    final previous = _settingsSaveTail;
    final completion = Completer<void>();
    final tail = completion.future;
    // Register before invoking persistence, whose callbacks may re-enter.
    _settingsSaveTail = tail;
    try {
      if (previous != null) await previous;
      if (!_isCurrentRequest(account, generation)) return false;
      final setting = update(_setting);
      _settingsRequest++;
      await repository.saveDashboardSetting(account: account, setting: setting);
      if (!_isCurrentRequest(account, generation)) return false;
      // Reads started before this write completed cannot restore old settings.
      _settingsRequest++;
      _setting = setting;
      notifyListeners();
      return _isCurrentRequest(account, generation);
    } catch (_) {
      if (!_isCurrentRequest(account, generation)) return false;
      rethrow;
    } finally {
      // Release queued changes even on failure; each caller receives its own
      // error, and the next change rebases on the last confirmed setting.
      if (identical(_settingsSaveTail, tail)) _settingsSaveTail = null;
      completion.complete();
    }
  }

  Future<void> changeEventCity({
    required String account,
    required String city,
  }) async {
    if (!await _saveSetting(
      account: account,
      update: (current) => current.copyWith(recommendEventCity: city),
    )) {
      return;
    }

    await refreshRecommendEvent(account: account);
  }

  Future<void> changePlaceCity({
    required String account,
    required String city,
  }) async {
    if (!await _saveSetting(
      account: account,
      update: (current) => current.copyWith(recommendPlaceCity: city),
    )) {
      return;
    }

    await refreshRecommendPlace(account: account);
  }

  Future<void> changeAccountingAccount({
    required String account,
    required String? accountId,
    required String? accountName,
  }) async {
    if (!await _saveSetting(
      account: account,
      update: (current) => current.copyWith(
        accountingAccountId: accountId,
        accountingAccountName: accountName,
      ),
    )) {
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
    if (!await _saveSetting(
      account: account,
      update: (current) => current.copyWith(
        pointAccountId: accountId,
        pointAccountName: accountName,
      ),
    )) {
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
