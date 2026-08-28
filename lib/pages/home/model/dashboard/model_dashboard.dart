import 'package:life_pilot/apps/config_app.dart';
import 'package:life_pilot/pages/home/model/accounting/income_expense_item.dart';
import 'package:life_pilot/pages/home/model/dashboard/dashboard_city.dart';
import 'package:life_pilot/pages/home/model/dashboard/dashboard_setting.dart';
import 'package:life_pilot/utils/safe_change_notifier.dart';
import 'package:life_pilot/pages/home/model/dashboard/dashboard_state.dart';
import 'package:life_pilot/pages/home/model/event/recommended_event.dart';
import 'package:life_pilot/pages/home/model/place/recommended_place.dart';
import 'package:life_pilot/pages/home/model/point/point_record_item.dart';
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

  ModelDashboard({
    required this.repository,
    required this.localeProvider,
  });

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
      _sectionLoadingCounts.update(section, (count) => count + 1,
          ifAbsent: () => 1);
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

  List<DashboardCity> get eventCities => _eventCities;

  List<DashboardCity> _placeCities = [];

  List<DashboardCity> get placeCities => _placeCities;

  void switchAccount(String? account) {
    _accountGeneration++;
    _activeAccount = account;
    _loading = false;
    _state = DashboardState.empty();
    _setting = DashboardSetting(
      recommendEventCity: '台北',
      recommendPlaceCity: '台北',
      language: localeProvider.locale.languageCode,
    );
    _eventCities = [];
    _placeCities = [];
    _sectionLoadingCounts.clear();
    _failedSections.clear();
    notifyListeners();
  }

  bool _isCurrentRequest(String account, int generation) =>
      _activeAccount == account && _accountGeneration == generation;

  Future<void> loadEventCities(String account) async {
    final generation = _accountGeneration;
    if (!_isCurrentRequest(account, generation)) return;
    List<DashboardCity> eventCities;
    try {
      eventCities = await repository.loadEventCities();
    } catch (error, stackTrace) {
      logger.e('Could not load recommended event cities.',
          error: error, stackTrace: stackTrace);
      return;
    }
    if (!_isCurrentRequest(account, generation)) return;
    _eventCities = eventCities;
    notifyListeners();
  }

  Future<void> loadPlaceCities(String account) async {
    final generation = _accountGeneration;
    if (!_isCurrentRequest(account, generation)) return;
    List<DashboardCity> placeCities;
    try {
      placeCities = await repository.loadPlaceCities();
    } catch (error, stackTrace) {
      logger.e('Could not load recommended place cities.',
          error: error, stackTrace: stackTrace);
      return;
    }
    if (!_isCurrentRequest(account, generation)) return;
    _placeCities = placeCities;
    notifyListeners();
  }

  Future<void> refreshAll({
    required String account,
  }) async {
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
      final todayEventsFuture = _loadSection(
        DashboardSection.todaySchedule,
        () => repository.loadTodayEvents(account),
      );
      DashboardSetting setting = _setting;
      try {
        final loadedSetting = await repository.loadDashboardSetting(
          account: account,
        );
        setting = loadedSetting.copyWith(
          language: localeProvider.locale.languageCode,
        );
      } catch (error, stackTrace) {
        logger.e('Could not load dashboard settings.',
            error: error, stackTrace: stackTrace);
      }
      if (!_isCurrentRequest(account, generation)) return;

      final configuredSections = await Future.wait([
        _loadSection(
          DashboardSection.recommendEvents,
          () => repository.loadRecommendEvents(setting.recommendEventCity),
        ),
        _loadSection(
          DashboardSection.recommendPlaces,
          () => repository.loadRecommendPlaces(setting.recommendPlaceCity),
        ),
        _loadSection(
          DashboardSection.accounting,
          () => repository.loadAccountingSummary(
            accountId: setting.accountingAccountId ?? '',
          ),
        ),
        _loadSection(
          DashboardSection.points,
          () => repository.loadPointSummary(
            accountId: setting.pointAccountId ?? '',
          ),
        ),
      ]);
      final todayEvents = await todayEventsFuture;
      if (!_isCurrentRequest(account, generation)) return;

      _setting = setting;
      _state = DashboardState(
        todayEvents: todayEvents ?? _state.todayEvents,
        recommendEvents: recommendEventRequest == _recommendEventRequest
            ? configuredSections[0] as List<RecommendedEvent>? ??
                _state.recommendEvents
            : _state.recommendEvents,
        recommendPlaces: recommendPlaceRequest == _recommendPlaceRequest
            ? configuredSections[1] as List<RecommendedPlace>? ??
                _state.recommendPlaces
            : _state.recommendPlaces,
        todayIncomeExpense: accountingRequest == _accountingRequest
            ? (configuredSections[2] as AccountingDashboardSummary?)?.records ??
                _state.todayIncomeExpense
            : _state.todayIncomeExpense,
        accountingTotal: accountingRequest == _accountingRequest
            ? (configuredSections[2] as AccountingDashboardSummary?)?.total ??
                _state.accountingTotal
            : _state.accountingTotal,
        accountingCurrency: accountingRequest == _accountingRequest
            ? (configuredSections[2] as AccountingDashboardSummary?)
                    ?.currency ??
                _state.accountingCurrency
            : _state.accountingCurrency,
        todayPoints: pointsRequest == _pointsRequest
            ? (configuredSections[3] as PointDashboardSummary?)?.records ??
                _state.todayPoints
            : _state.todayPoints,
        pointsTotal: pointsRequest == _pointsRequest
            ? (configuredSections[3] as PointDashboardSummary?)?.total ??
                _state.pointsTotal
            : _state.pointsTotal,
      );
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
      logger.e('Could not load dashboard section: $section.',
          error: error, stackTrace: stackTrace);
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

  Future<void> refreshTodaySchedule({
    required String account,
  }) async {
    final generation = _accountGeneration;
    if (!_isCurrentRequest(account, generation)) return;
    _loading = true;
    _beginLoading(const [DashboardSection.todaySchedule]);
    notifyListeners();

    try {
      final todayEvents = await repository.loadTodayEvents(account);
      if (!_isCurrentRequest(account, generation)) return;

      _state = _state.copyWith(
        todayEvents: todayEvents,
      );
    } finally {
      if (_isCurrentRequest(account, generation)) {
        _loading = false;
        _endLoading(const [DashboardSection.todaySchedule]);
        notifyListeners();
      }
    }
  }

  Future<void> refreshRecommendEvent({
    required String account,
  }) async {
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

      _state = _state.copyWith(
        recommendEvents: recommendedEvents,
      );
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

  Future<void> refreshRecommendPlace({
    required String account,
  }) async {
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

      _state = _state.copyWith(
        recommendPlaces: recommendedPlaces,
      );
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

  Future<void> refreshAccounting({
    required String accountId,
  }) async {
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

  Future<void> refreshPoints({
    required String accountId,
  }) async {
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
    await repository.completeEvent(
      id: id,
      account: account,
    );

    await refreshTodaySchedule(
      account: account,
    );
  }

  Future<void> changeEventCity({
    required String account,
    required String city,
  }) async {
    final updatedSetting = _setting.copyWith(
      recommendEventCity: city,
    );

    await repository.saveDashboardSetting(
      account: account,
      setting: updatedSetting,
    );

    _setting = updatedSetting;
    notifyListeners();

    await refreshRecommendEvent(
      account: account,
    );
  }

  Future<void> changePlaceCity({
    required String account,
    required String city,
  }) async {
    final updatedSetting = _setting.copyWith(
      recommendPlaceCity: city,
    );

    await repository.saveDashboardSetting(
      account: account,
      setting: updatedSetting,
    );

    _setting = updatedSetting;
    notifyListeners();

    await refreshRecommendPlace(
      account: account,
    );
  }

  Future<void> changeLanguage({
    required String account,
    required String language,
  }) async {
    _setting = _setting.copyWith(
      language: language,
    );

    await repository.saveDashboardSetting(
      account: account,
      setting: _setting,
    );

    await refreshAll(
      account: account,
    );
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

    await repository.saveDashboardSetting(
      account: account,
      setting: updatedSetting,
    );

    _setting = updatedSetting;
    notifyListeners();

    if (accountId == null) {
      _accountingRequest++;
      _failedSections.remove(DashboardSection.accounting);
      _state = _state.copyWith(
        todayIncomeExpense: const [],
        accountingTotal: 0,
        accountingCurrency: 'TWD',
      );
      notifyListeners();
    } else {
      _failedSections.remove(DashboardSection.accounting);
      _state = _state.copyWith(
        todayIncomeExpense: const [],
        accountingTotal: 0,
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

    await repository.saveDashboardSetting(
      account: account,
      setting: updatedSetting,
    );

    _setting = updatedSetting;
    notifyListeners();

    if (accountId == null) {
      _pointsRequest++;
      _failedSections.remove(DashboardSection.points);
      _state = _state.copyWith(
        todayPoints: const [],
        pointsTotal: 0,
      );
      notifyListeners();
    } else {
      _failedSections.remove(DashboardSection.points);
      _state = _state.copyWith(
        todayPoints: const [],
        pointsTotal: 0,
      );
      notifyListeners();
      await refreshPoints(accountId: accountId);
    }
  }
}
