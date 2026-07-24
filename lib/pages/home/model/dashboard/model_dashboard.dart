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

class ModelDashboard extends ChangeNotifier {
  final DashboardRepository repository;

  ModelDashboard({
    required this.repository,
  });

  bool _loading = false;

  bool get loading => _loading;

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

  Future<void> loadEventCities(String account) async {
    _eventCities = await repository.loadEventCities(account);
    notifyListeners();
  }

  Future<void> loadPlaceCities(String account) async {
    _placeCities = await repository.loadPlaceCities(account);
    notifyListeners();
  }

  Future<void> refreshAll({
    required String account,
  }) async {
    _loading = true;
    notifyListeners();

    try {
      _setting = await repository.loadDashboardSetting(
        account: account,
      );

      final result = await Future.wait([
        repository.loadTodayEvents(account),
        repository.loadRecommendEvents(account, _setting.recommendEventCity),
        repository.loadRecommendPlaces(account, _setting.recommendPlaceCity),
        repository.loadTodayIncomeExpense(
          _setting.accountingAccountName ?? account,
        ),
        repository.loadPoints(_setting.pointAccountName ?? account),
      ]);

      _state = DashboardState(
        todayEvents: result[0] as List<CalendarEvent>,
        recommendEvents: result[1] as List<RecommendedEvent>,
        recommendPlaces: result[2] as List<RecommendedPlace>,
        todayIncomeExpense: result[3] as List<IncomeExpenseItem>,
        todayPoints: result[4] as List<PointRecordItem>,
      );
    } finally {
      _loading = false;
      notifyListeners();
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
    _loading = true;
    notifyListeners();

    try {
      _setting = await repository.loadDashboardSetting(
        account: account,
      );

      final recommendedEvents =
          await repository.loadRecommendEvents(account, _setting.recommendEventCity);

      _state = _state.copyWith(
          recommendEvents: recommendedEvents,);
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> refreshRecommendPlace({
    required String account,
  }) async {
    _loading = true;
    notifyListeners();

    try {
      _setting = await repository.loadDashboardSetting(
        account: account,
      );

      final recommendedPlaces =
          await repository.loadRecommendPlaces(account, _setting.recommendPlaceCity);

      _state = _state.copyWith(
          recommendPlaces: recommendedPlaces,);
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> refreshAccounting({
    required String account,
  }) async {
    _loading = true;
    notifyListeners();

    try {
      _setting = await repository.loadDashboardSetting(
        account: account,
      );

      final todayIncomeExpense = await repository.loadTodayIncomeExpense(
        _setting.accountingAccountId ?? account,
      );

      _state = _state.copyWith(todayIncomeExpense: todayIncomeExpense);
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> refreshPoints({
    required String account,
  }) async {
    _loading = true;
    notifyListeners();

    try {
      _setting = await repository.loadDashboardSetting(
        account: account,
      );

      final todayPoints =
          await repository.loadPoints(_setting.pointAccountId ?? account);

      _state = _state.copyWith(todayPoints: todayPoints);
      
    } finally {
      _loading = false;
      notifyListeners();
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
    _setting = _setting.copyWith(
      recommendEventCity: city,
    );

    await repository.saveDashboardSetting(
      account: account,
      setting: _setting,
    );

    await refreshRecommendEvent(
      account: account,
    );
  }

  Future<void> changePlaceCity({
    required String account,
    required String city,
  }) async {
    _setting = _setting.copyWith(
      recommendPlaceCity: city,
    );

    await repository.saveDashboardSetting(
      account: account,
      setting: _setting,
    );

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
    required String accountId,
    required String accountName,
  }) async {
    _setting = _setting.copyWith(
      accountingAccountId: accountId,
      accountingAccountName: accountName,
    );

    await repository.saveDashboardSetting(
      account: account,
      setting: _setting,
    );

    await refreshAccounting(
      account: account,
    );

    notifyListeners();
  }

  Future<void> changePointAccount({
    required String account,
    required String accountId,
    required String accountName,
  }) async {
    _setting = _setting.copyWith(
      pointAccountId: accountId,
      pointAccountName: accountName,
    );

    await repository.saveDashboardSetting(
      account: account,
      setting: _setting,
    );

    await refreshPoints(
      account: account,
    );

    notifyListeners();
  }
}
