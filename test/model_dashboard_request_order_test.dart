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
    final model = _model(repository);

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

  Future<List<IncomeExpenseItem>> loadTodayIncomeExpense(
      {required String accountId}) {
    _accountingCalls++;
    return _accountingCalls == 1
        ? oldAccounting.future
        : Future.value([_income('new')]);
  }

  Future<List<PointRecordItem>> loadPoints({required String accountId}) async =>
      [];
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

  Future<List<IncomeExpenseItem>> loadTodayIncomeExpense({
    required String accountId,
  }) async =>
      [_income('record')];

  Future<List<PointRecordItem>> loadPoints({required String accountId}) async =>
      [PointRecordItem(description: 'record', type: 'point', value: 1)];
}
