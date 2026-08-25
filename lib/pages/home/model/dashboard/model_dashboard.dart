import 'package:flutter/material.dart';
import 'package:life_pilot/apps/config_app.dart';
import 'package:life_pilot/pages/home/model/accounting/income_expense_item.dart';
import 'package:life_pilot/pages/home/model/dashboard/dashboard_city.dart';
import 'package:life_pilot/pages/home/model/dashboard/dashboard_setting.dart';
import 'package:life_pilot/pages/home/model/event/calendar_event.dart';
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

class ModelDashboard extends ChangeNotifier {
  final DashboardRepository repository;
  final ProviderLocale localeProvider;
  int _accountGeneration = 0;
  String? _activeAccount;

  ModelDashboard({
    required this.repository,
    required this.localeProvider,
  });

  bool _loading = false;
  final Set<DashboardSection> _failedSections = {};
  int _recommendEventRequest = 0;
  int _recommendPlaceRequest = 0;
  int _accountingRequest = 0;
  int _pointsRequest = 0;

  bool get loading => _loading;

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
    final generation = _accountGeneration;
    final recommendEventRequest = ++_recommendEventRequest;
    final recommendPlaceRequest = ++_recommendPlaceRequest;
    final accountingRequest = ++_accountingRequest;
    final pointsRequest = ++_pointsRequest;
    if (!_isCurrentRequest(account, generation)) return;
    _loading = true;
    _failedSections.clear();
    notifyListeners();

    try {
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

      final result = await Future.wait([
        _loadSection(
          DashboardSection.todaySchedule,
          () => repository.loadTodayEvents(account),
        ),
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
          () => repository.loadTodayIncomeExpense(
            accountId: setting.accountingAccountId ?? '',
          ),
        ),
        _loadSection(
          DashboardSection.points,
          () => repository.loadPoints(accountId: setting.pointAccountId ?? ''),
        ),
      ]);
      if (!_isCurrentRequest(account, generation)) return;

      _setting = setting;
      _state = DashboardState(
        todayEvents: result[0] as List<CalendarEvent>? ?? _state.todayEvents,
        recommendEvents: recommendEventRequest == _recommendEventRequest
            ? result[1] as List<RecommendedEvent>? ?? _state.recommendEvents
            : _state.recommendEvents,
        recommendPlaces: recommendPlaceRequest == _recommendPlaceRequest
            ? result[2] as List<RecommendedPlace>? ?? _state.recommendPlaces
            : _state.recommendPlaces,
        todayIncomeExpense: accountingRequest == _accountingRequest
            ? result[3] as List<IncomeExpenseItem>? ?? _state.todayIncomeExpense
            : _state.todayIncomeExpense,
        todayPoints: pointsRequest == _pointsRequest
            ? result[4] as List<PointRecordItem>? ?? _state.todayPoints
            : _state.todayPoints,
      );
    } finally {
      if (_isCurrentRequest(account, generation)) {
        _loading = false;
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

  Future<void> refreshTodaySchedule({
    required String account,
  }) async {
    _loading = true;
    notifyListeners();

    try {
      _setting = await repository.loadDashboardSetting(
        account: account,
      );

      final todayEvents = await repository.loadTodayEvents(account);

      _state = _state.copyWith(
        todayEvents: todayEvents,
      );
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> refreshRecommendEvent({
    required String account,
  }) async {
    final request = ++_recommendEventRequest;
    _loading = true;
    notifyListeners();

    try {
      final setting = await repository.loadDashboardSetting(
        account: account,
      );

      final recommendedEvents =
          await repository.loadRecommendEvents(setting.recommendEventCity);

      if (request != _recommendEventRequest) return;

      _setting = setting;
      _state = _state.copyWith(
        recommendEvents: recommendedEvents,
      );
    } finally {
      if (request == _recommendEventRequest) {
        _loading = false;
        notifyListeners();
      }
    }
  }

  Future<void> refreshRecommendPlace({
    required String account,
  }) async {
    final request = ++_recommendPlaceRequest;
    _loading = true;
    notifyListeners();

    try {
      final setting = await repository.loadDashboardSetting(
        account: account,
      );

      final recommendedPlaces =
          await repository.loadRecommendPlaces(setting.recommendPlaceCity);

      if (request != _recommendPlaceRequest) return;

      _setting = setting;
      _state = _state.copyWith(
        recommendPlaces: recommendedPlaces,
      );
    } finally {
      if (request == _recommendPlaceRequest) {
        _loading = false;
        notifyListeners();
      }
    }
  }

  Future<void> refreshAccounting({
    required String accountId,
  }) async {
    final request = ++_accountingRequest;
    _loading = true;
    notifyListeners();

    try {
      final todayIncomeExpense = await repository.loadTodayIncomeExpense(
        accountId: accountId,
      );

      if (request != _accountingRequest) return;

      _failedSections.remove(DashboardSection.accounting);
      _state = _state.copyWith(todayIncomeExpense: todayIncomeExpense);
    } finally {
      if (request == _accountingRequest) {
        _loading = false;
        notifyListeners();
      }
    }
  }

  Future<void> refreshPoints({
    required String accountId,
  }) async {
    final request = ++_pointsRequest;
    _loading = true;
    notifyListeners();

    try {
      final todayPoints = await repository.loadPoints(accountId: accountId);

      if (request != _pointsRequest) return;

      _failedSections.remove(DashboardSection.points);
      _state = _state.copyWith(todayPoints: todayPoints);
    } finally {
      if (request == _pointsRequest) {
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
      _state = _state.copyWith(todayIncomeExpense: const []);
      notifyListeners();
    } else {
      _failedSections.remove(DashboardSection.accounting);
      _state = _state.copyWith(todayIncomeExpense: const []);
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
      _state = _state.copyWith(todayPoints: const []);
      notifyListeners();
    } else {
      _failedSections.remove(DashboardSection.points);
      _state = _state.copyWith(todayPoints: const []);
      notifyListeners();
      await refreshPoints(accountId: accountId);
    }
  }
}
