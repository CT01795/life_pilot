import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/pages/home/model/dashboard/dashboard_setting.dart';
import 'package:life_pilot/pages/home/model/dashboard/model_dashboard.dart';
import 'package:life_pilot/pages/home/model/accounting/income_expense_item.dart';
import 'package:life_pilot/pages/home/model/point/point_record_item.dart';
import 'package:life_pilot/pages/home/model/event/calendar_event.dart';
import 'package:life_pilot/pages/home/model/event/recommended_event.dart';
import 'package:life_pilot/pages/home/model/place/recommended_place.dart';
import 'package:life_pilot/pages/home/repository/repository_dashboard.dart';
import 'package:life_pilot/utils/provider_locale.dart';

class _Repository extends DashboardRepository {
  final saves =
      <({String account, DashboardSetting setting, Completer<void> done})>[];
  int reads = 0;

  @override
  Future<void> saveDashboardSetting({
    required String account,
    required DashboardSetting setting,
  }) {
    final done = Completer<void>();
    saves.add((account: account, setting: setting, done: done));
    return done.future;
  }

  @override
  Future<DashboardSetting> loadDashboardSetting({
    required String account,
  }) async {
    reads++;
    return saves.last.setting.copyWith();
  }

  @override
  Future<List<RecommendedEvent>> loadRecommendEvents(String city) async {
    reads++;
    return [];
  }

  @override
  Future<List<RecommendedPlace>> loadRecommendPlaces(String city) async {
    reads++;
    return [];
  }

  @override
  Future<List<CalendarEvent>> loadTodayEvents(String account) async {
    reads++;
    return [];
  }

  @override
  Future<AccountingDashboardSummary> loadAccountingSummary({
    required String accountId,
  }) async {
    reads++;
    return const AccountingDashboardSummary.empty();
  }

  @override
  Future<PointDashboardSummary> loadPointSummary({
    required String accountId,
  }) async {
    reads++;
    return const PointDashboardSummary.empty();
  }
}

final changes = <String, Future<void> Function(ModelDashboard, String)>{
  'event city': (model, account) =>
      model.changeEventCity(account: account, city: '台中'),
  'place city': (model, account) =>
      model.changePlaceCity(account: account, city: '高雄'),
  'accounting': (model, account) => model.changeAccountingAccount(
    account: account,
    accountId: 'money',
    accountName: 'Money',
  ),
  'points': (model, account) => model.changePointAccount(
    account: account,
    accountId: 'points',
    accountName: 'Points',
  ),
  'language': (model, account) =>
      model.changeLanguage(account: account, language: 'en'),
};

void main() {
  late _Repository repository;
  late ModelDashboard model;
  setUp(() {
    repository = _Repository();
    model = ModelDashboard(
      repository: repository,
      localeProvider: ProviderLocale(locale: const Locale('zh')),
    )..switchAccount('old');
  });
  tearDown(() {
    if (!model.notifierDisposed) model.dispose();
  });

  for (final change in changes.entries) {
    test('${change.key}: inactive account cannot save or refresh', () async {
      model.switchAccount('new');
      final before = model.setting;
      await change.value(model, 'old');
      expect(repository.saves, isEmpty);
      expect(repository.reads, 0);
      expect(identical(model.setting, before), isTrue);
    });

    test('${change.key}: late save cannot overwrite another account', () async {
      final pending = change.value(model, 'old');
      expect(repository.saves.single.account, 'old');
      model.switchAccount('new');
      final before = model.setting;
      var notifications = 0;
      model.addListener(() => notifications++);
      repository.saves.single.done.complete();
      await pending;
      expect(identical(model.setting, before), isTrue);
      expect(repository.reads, 0);
      expect(notifications, 0);
    });

    test(
      '${change.key}: disposed model ignores a pending save completion',
      () async {
        final pending = change.value(model, 'old');
        final before = model.setting;
        model.dispose();
        repository.saves.single.done.complete();
        await pending;
        expect(identical(model.setting, before), isTrue);
        expect(repository.reads, 0);
      },
    );

    test(
      '${change.key}: current account still publishes and refreshes',
      () async {
        final pending = change.value(model, 'old');
        final saved = repository.saves.single.setting;
        repository.saves.single.done.complete();
        await pending;
        // Language refresh retains the active UI locale as before.
        if (change.key != 'language') {
          expect(model.setting.toJson(), saved.toJson());
        }
        expect(repository.reads, greaterThan(0));
        expect(model.loading, isFalse);
      },
    );
  }

  test(
    'signing back into the same email does not revive an old save',
    () async {
      final pending = model.changeEventCity(account: 'old', city: '台中');
      model.switchAccount(null);
      model.switchAccount('old');
      final before = model.setting;
      repository.saves.single.done.complete();
      await pending;
      expect(identical(model.setting, before), isTrue);
      expect(repository.reads, 0);
    },
  );

  test(
    'account switch inside notification prevents a follow-up refresh',
    () async {
      final pending = model.changeEventCity(account: 'old', city: '台中');
      model.addListener(() {
        if (model.setting.recommendEventCity == '台中') {
          model.switchAccount('new');
        }
      });
      repository.saves.single.done.complete();
      await pending;
      expect(model.setting.recommendEventCity, '台北');
      expect(repository.reads, 0);
    },
  );

  test('save failure is propagated and does not launch a refresh', () async {
    final before = model.setting;
    final pending = model.changeEventCity(account: 'old', city: '台中');
    final expectation = expectLater(pending, throwsStateError);
    repository.saves.single.done.completeError(StateError('save failed'));
    await expectation;
    expect(identical(model.setting, before), isTrue);
    expect(repository.reads, 0);
  });
}
