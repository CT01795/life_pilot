import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/pages/home/model/dashboard/dashboard_setting.dart';
import 'package:life_pilot/pages/home/controller_dashboard.dart';
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
  void Function()? onSave;
  bool gateSettings = false;
  final settingsReads = <Completer<DashboardSetting>>[];

  @override
  Future<void> saveDashboardSetting({
    required String account,
    required DashboardSetting setting,
  }) {
    final done = Completer<void>();
    saves.add((account: account, setting: setting, done: done));
    onSave?.call();
    return done.future;
  }

  @override
  Future<DashboardSetting> loadDashboardSetting({
    required String account,
  }) async {
    reads++;
    if (gateSettings) {
      final done = Completer<DashboardSetting>();
      settingsReads.add(done);
      return done.future;
    }
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

final changes = <String, Future<void> Function(ControllerDashboard, String)>{
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
  late ControllerDashboard model;
  setUp(() {
    repository = _Repository();
    model = ControllerDashboard(
      repository: repository,
      localeProvider: ProviderLocale(locale: const Locale('zh')),
    )..switchAccount('old');
  });
  tearDown(() {
    if (!model.notifierDisposed) model.dispose();
  });

  test(
    'queued changes merge different setting fields instead of overwriting them',
    () async {
      final event = model.changeEventCity(account: 'old', city: '台中');
      final place = model.changePlaceCity(account: 'old', city: '高雄');
      final accounting = model.changeAccountingAccount(
        account: 'old',
        accountId: 'cash',
        accountName: 'Cash',
      );
      final points = model.changePointAccount(
        account: 'old',
        accountId: 'points',
        accountName: 'Points',
      );
      expect(repository.saves.length, 1);
      for (var i = 0; i < 4; i++) {
        expect(repository.saves.length, i + 1);
        repository.saves[i].done.complete();
        await Future<void>.delayed(Duration.zero);
      }
      await Future.wait([event, place, accounting, points]);
      final saved = repository.saves.last.setting;
      expect(saved.recommendEventCity, '台中');
      expect(saved.recommendPlaceCity, '高雄');
      expect(saved.accountingAccountId, 'cash');
      expect(saved.pointAccountId, 'points');
      expect(model.setting.toJson(), saved.toJson());
    },
  );

  test(
    'successive edits to the same city persist in invocation order',
    () async {
      final a = model.changeEventCity(account: 'old', city: '台中');
      final b = model.changeEventCity(account: 'old', city: '高雄');
      expect(repository.saves.length, 1);
      repository.saves.first.done.complete();
      await Future<void>.delayed(Duration.zero);
      expect(repository.saves.map((s) => s.setting.recommendEventCity), [
        '台中',
        '高雄',
      ]);
      repository.saves.last.done.complete();
      await Future.wait([a, b]);
      expect(model.setting.recommendEventCity, '高雄');
    },
  );

  test(
    'failed write releases queued changes without merging uncommitted fields',
    () async {
      final first = model.changeEventCity(account: 'old', city: '台中');
      final checked = expectLater(first, throwsStateError);
      final next = model.changePlaceCity(account: 'old', city: '高雄');
      repository.saves.first.done.completeError(StateError('offline'));
      await checked;
      await Future<void>.delayed(Duration.zero);
      expect(repository.saves.last.setting.recommendEventCity, '台北');
      expect(repository.saves.last.setting.recommendPlaceCity, '高雄');
      repository.saves.last.done.complete();
      await next;
      expect(model.setting.recommendEventCity, '台北');
    },
  );

  for (final oldFails in [false, true]) {
    test(
      'account switch releases new writes and skips the old queue (old fails=$oldFails)',
      () async {
        final old = model.changeEventCity(account: 'old', city: '台中');
        final queued = model.changePlaceCity(account: 'old', city: '高雄');
        model.switchAccount('new');
        final fresh = model.changePlaceCity(account: 'new', city: '台南');
        expect(repository.saves.map((s) => s.account), ['old', 'new']);
        repository.saves.last.done.complete();
        await fresh;
        if (oldFails) {
          repository.saves.first.done.completeError(StateError('old account'));
        } else {
          repository.saves.first.done.complete();
        }
        await Future.wait([old, queued]);
        expect(repository.saves.length, 2);
        expect(model.setting.recommendEventCity, '台北');
        expect(model.setting.recommendPlaceCity, '台南');
      },
    );
  }

  test(
    'repository reentry joins the ordered queue before any second write',
    () async {
      Future<void>? nested;
      repository.onSave = () {
        nested ??= model.changePlaceCity(account: 'old', city: '高雄');
      };
      final first = model.changeEventCity(account: 'old', city: '台中');
      expect(repository.saves.length, 1);
      repository.onSave = null;
      repository.saves.first.done.complete();
      await Future<void>.delayed(Duration.zero);
      expect(repository.saves.length, 2);
      expect(repository.saves.last.setting.recommendEventCity, '台中');
      repository.saves.last.done.complete();
      await Future.wait([first, nested!]);
      expect(model.setting.recommendPlaceCity, '高雄');
    },
  );

  test(
    'settings read completing after a saved edit cannot restore the old city',
    () async {
      // Give this fake a saved baseline before the refresh reads it.
      final seed = model.changeEventCity(account: 'old', city: '台中');
      repository.saves.single.done.complete();
      await seed;
      repository.gateSettings = true;
      final refresh = model.refreshCore(account: 'old');
      final oldSetting = model.setting.copyWith();
      final write = model.changeEventCity(account: 'old', city: '台南');
      repository.saves.last.done.complete();
      await write;
      repository.settingsReads.single.complete(oldSetting);
      await refresh;
      expect(model.setting.recommendEventCity, '台南');
    },
  );

  test(
    'failed optimistic language edit rolls back before the next patch',
    () async {
      final language = model.changeLanguage(account: 'old', language: 'en');
      final checked = expectLater(language, throwsStateError);
      final city = model.changeEventCity(account: 'old', city: '台中');
      repository.saves.first.done.completeError(StateError('offline'));
      await checked;
      await Future<void>.delayed(Duration.zero);
      expect(repository.saves.last.setting.language, 'zh');
      repository.saves.last.done.complete();
      await city;
      expect(model.setting.language, 'zh');
    },
  );

  test(
    'finishing an old account queue cannot release the new account queue',
    () async {
      final old = model.changeEventCity(account: 'old', city: '台中');
      final oldQueued = model.changePlaceCity(account: 'old', city: '高雄');
      model.switchAccount('new');
      final fresh = model.changeEventCity(account: 'new', city: '台南');
      repository.saves.first.done.complete();
      await Future.wait([old, oldQueued]);
      final next = model.changePlaceCity(account: 'new', city: '新北');
      expect(repository.saves.length, 2);
      repository.saves[1].done.complete();
      await Future<void>.delayed(Duration.zero);
      expect(repository.saves.length, 3);
      expect(repository.saves.last.account, 'new');
      expect(repository.saves.last.setting.recommendEventCity, '台南');
      repository.saves.last.done.complete();
      await Future.wait([fresh, next]);
    },
  );

  test('disposal skips queued settings and their follow-up reads', () async {
    final first = model.changeEventCity(account: 'old', city: '台中');
    final next = model.changePlaceCity(account: 'old', city: '高雄');
    model.dispose();
    repository.saves.first.done.complete();
    await Future.wait([first, next]);
    expect(repository.saves.length, 1);
    expect(repository.reads, 0);
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
