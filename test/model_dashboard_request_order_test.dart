import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/pages/home/model/accounting/income_expense_item.dart';
import 'package:life_pilot/pages/home/model/dashboard/dashboard_setting.dart';
import 'package:life_pilot/pages/home/model/dashboard/model_dashboard.dart';
import 'package:life_pilot/pages/home/model/event/calendar_event.dart';
import 'package:life_pilot/pages/home/model/event/recommended_event.dart';
import 'package:life_pilot/pages/home/model/place/recommended_place.dart';
import 'package:life_pilot/pages/home/model/point/point_record_item.dart';
import 'package:life_pilot/pages/home/repository/repository_dashboard.dart';
import 'package:life_pilot/utils/provider_locale.dart';

void main() {
  test('latest recommendation request wins when an older request finishes last',
      () async {
    final repository = _RecommendationOrderRepository();
    final model = _model(repository)..switchAccount('user');

    final firstRequest = model.refreshRecommendEvent(account: 'user');
    final secondRequest = model.refreshRecommendEvent(account: 'user');

    repository.secondEvents.complete([_event('new')]);
    await secondRequest;
    repository.firstEvents.complete([_event('old')]);
    await firstRequest;

    expect(model.state.recommendEvents.single.name, 'new');
  });

  test('late full refresh cannot overwrite a newer accounting selection',
      () async {
    final repository = _RefreshOrderRepository();
    final model = _model(repository);
    model.switchAccount('user');

    final fullRefresh = model.refreshAll(account: 'user');
    await Future<void>.delayed(Duration.zero);
    final latestSelection = model.refreshAccounting(accountId: 'new-account');
    await latestSelection;

    repository.oldAccounting.complete([_income('old')]);
    await fullRefresh;

    expect(model.state.todayIncomeExpense.single.description, 'new');
  });

  test('request from the previous user cannot update the dashboard', () async {
    final repository = _AccountSwitchRepository();
    final model = _model(repository)..switchAccount('first-user');

    final oldRequest = model.refreshRecommendEvent(account: 'first-user');
    await Future<void>.delayed(Duration.zero);
    model.switchAccount('second-user');

    repository.oldEvents.complete([_event('old-user-event')]);
    await oldRequest;

    expect(model.state.recommendEvents, isEmpty);
    expect(model.isLoading(DashboardSection.recommendEvents), isFalse);
  });

  test('clearing dashboard accounts removes saved selections and records',
      () async {
    final repository = _ClearSelectionRepository();
    final model = _model(repository)..switchAccount('user');

    await model.refreshAccounting(accountId: 'account');
    await model.refreshPoints(accountId: 'points');
    expect(model.state.todayIncomeExpense, isNotEmpty);
    expect(model.state.todayPoints, isNotEmpty);

    await model.changeAccountingAccount(
      account: 'user',
      accountId: null,
      accountName: null,
    );
    await model.changePointAccount(
      account: 'user',
      accountId: null,
      accountName: null,
    );

    expect(model.setting.accountingAccountId, isNull);
    expect(model.setting.accountingAccountName, isNull);
    expect(model.setting.pointAccountId, isNull);
    expect(model.setting.pointAccountName, isNull);
    expect(model.state.todayIncomeExpense, isEmpty);
    expect(model.state.todayPoints, isEmpty);
    expect(repository.savedSetting?.accountingAccountId, isNull);
    expect(repository.savedSetting?.pointAccountId, isNull);
  });

  test('selecting dashboard accounts immediately reloads homepage records',
      () async {
    final repository = _ClearSelectionRepository();
    final model = _model(repository)..switchAccount('user');

    await model.changeAccountingAccount(
      account: 'user',
      accountId: 'account',
      accountName: 'Accounting',
    );
    await model.changePointAccount(
      account: 'user',
      accountId: 'points',
      accountName: 'Points',
    );

    expect(model.state.todayIncomeExpense.single.description, 'record');
    expect(model.state.todayPoints.single.description, 'record');
    expect(repository.savedSetting?.accountingAccountId, 'account');
    expect(repository.savedSetting?.pointAccountId, 'points');
  });

  test('section refreshes reuse loaded settings without another settings query',
      () async {
    final repository = _SectionRefreshRepository();
    final model = _model(repository)..switchAccount('user');

    await model.refreshTodaySchedule(account: 'user');
    await model.refreshRecommendEvent(account: 'user');
    await model.refreshRecommendPlace(account: 'user');

    expect(repository.settingLoadCount, 0);
    expect(repository.eventCity, model.setting.recommendEventCity);
    expect(repository.placeCity, model.setting.recommendPlaceCity);
  });

  test('full refresh starts today schedule while settings are loading',
      () async {
    final repository = _ParallelInitialLoadRepository();
    final model = _model(repository)..switchAccount('user');

    final refresh = model.refreshAll(account: 'user');
    await Future<void>.delayed(Duration.zero);

    expect(repository.todayEventsStarted, isTrue);

    repository.setting.complete(_setting());
    await refresh;
  });
}

ModelDashboard _model(DashboardRepository repository) => ModelDashboard(
      repository: repository,
      localeProvider: ProviderLocale(locale: const Locale('zh')),
    );

RecommendedEvent _event(String name) => RecommendedEvent(id: name, name: name);

IncomeExpenseItem _income(String description) => IncomeExpenseItem(
      description: description,
      value: 1,
      currency: 'TWD',
    );

DashboardSetting _setting() => DashboardSetting(
      recommendEventCity: '台北',
      recommendPlaceCity: '台北',
      language: 'zh',
      accountingAccountId: 'old-account',
      pointAccountId: 'point-account',
    );

class _RecommendationOrderRepository extends DashboardRepository {
  final firstEvents = Completer<List<RecommendedEvent>>();
  final secondEvents = Completer<List<RecommendedEvent>>();
  int _eventCalls = 0;

  @override
  Future<DashboardSetting> loadDashboardSetting(
          {required String account}) async =>
      _setting();

  @override
  Future<List<RecommendedEvent>> loadRecommendEvents(String city) {
    _eventCalls++;
    return _eventCalls == 1 ? firstEvents.future : secondEvents.future;
  }
}

class _RefreshOrderRepository extends DashboardRepository {
  final oldAccounting = Completer<List<IncomeExpenseItem>>();
  int _accountingCalls = 0;

  @override
  Future<DashboardSetting> loadDashboardSetting(
          {required String account}) async =>
      _setting();

  @override
  Future<List<CalendarEvent>> loadTodayEvents(String account) async => [];

  @override
  Future<List<RecommendedEvent>> loadRecommendEvents(String city) async => [];

  @override
  Future<List<RecommendedPlace>> loadRecommendPlaces(String city) async => [];

  @override
  Future<AccountingDashboardSummary> loadAccountingSummary(
      {required String accountId}) {
    _accountingCalls++;
    return _accountingCalls == 1
        ? oldAccounting.future.then(
            (records) => AccountingDashboardSummary(
              records: records,
              total: 1,
              currency: 'TWD',
            ),
          )
        : Future.value(
            AccountingDashboardSummary(
              records: [_income('new')],
              total: 1,
              currency: 'TWD',
            ),
          );
  }

  @override
  Future<PointDashboardSummary> loadPointSummary(
          {required String accountId}) async =>
      const PointDashboardSummary.empty();
}

class _AccountSwitchRepository extends DashboardRepository {
  final oldEvents = Completer<List<RecommendedEvent>>();

  @override
  Future<DashboardSetting> loadDashboardSetting(
          {required String account}) async =>
      _setting();

  @override
  Future<List<RecommendedEvent>> loadRecommendEvents(String city) =>
      oldEvents.future;
}

class _SectionRefreshRepository extends DashboardRepository {
  int settingLoadCount = 0;
  String? eventCity;
  String? placeCity;

  @override
  Future<DashboardSetting> loadDashboardSetting(
      {required String account}) async {
    settingLoadCount++;
    return _setting();
  }

  @override
  Future<List<CalendarEvent>> loadTodayEvents(String account) async => [];

  @override
  Future<List<RecommendedEvent>> loadRecommendEvents(String city) async {
    eventCity = city;
    return [];
  }

  @override
  Future<List<RecommendedPlace>> loadRecommendPlaces(String city) async {
    placeCity = city;
    return [];
  }
}

class _ParallelInitialLoadRepository extends DashboardRepository {
  final setting = Completer<DashboardSetting>();
  bool todayEventsStarted = false;

  @override
  Future<DashboardSetting> loadDashboardSetting({required String account}) =>
      setting.future;

  @override
  Future<List<CalendarEvent>> loadTodayEvents(String account) async {
    todayEventsStarted = true;
    return [];
  }

  @override
  Future<List<RecommendedEvent>> loadRecommendEvents(String city) async => [];

  @override
  Future<List<RecommendedPlace>> loadRecommendPlaces(String city) async => [];

  @override
  Future<AccountingDashboardSummary> loadAccountingSummary({
    required String accountId,
  }) async =>
      const AccountingDashboardSummary.empty();

  @override
  Future<PointDashboardSummary> loadPointSummary({
    required String accountId,
  }) async =>
      const PointDashboardSummary.empty();
}

class _ClearSelectionRepository extends DashboardRepository {
  DashboardSetting? savedSetting;

  @override
  Future<void> saveDashboardSetting({
    required String account,
    required DashboardSetting setting,
  }) async {
    savedSetting = setting;
  }

  @override
  Future<AccountingDashboardSummary> loadAccountingSummary({
    required String accountId,
  }) async =>
      AccountingDashboardSummary(
        records: [_income('record')],
        total: 1,
        currency: 'TWD',
      );

  @override
  Future<PointDashboardSummary> loadPointSummary({
    required String accountId,
  }) async =>
      PointDashboardSummary(
        records: [
          PointRecordItem(description: 'record', type: 'point', value: 1),
        ],
        total: 1,
      );
}
