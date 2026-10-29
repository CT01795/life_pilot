import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/pages/home/controller_dashboard.dart';
import 'package:life_pilot/pages/home/model/dashboard/dashboard_setting.dart';
import 'package:life_pilot/pages/home/model/accounting/income_expense_item.dart';
import 'package:life_pilot/pages/home/model/point/point_record_item.dart';
import 'package:life_pilot/pages/home/model/event/calendar_event.dart';
import 'package:life_pilot/pages/home/model/event/recommended_event.dart';
import 'package:life_pilot/pages/home/model/place/recommended_place.dart';
import 'package:life_pilot/pages/home/repository/repository_dashboard.dart';
import 'package:life_pilot/utils/provider_locale.dart';

DashboardSetting _setting() => DashboardSetting(
  recommendEventCity: '',
  recommendPlaceCity: '',
  language: 'en',
  accountingAccountId: 'cash',
  pointAccountId: 'points',
);

class _Repository extends DashboardRepository {
  int settingsReads = 0;
  void Function()? onSettingsRead;
  DashboardSection? target;
  bool gateSettings = false;
  final settings = <Completer<DashboardSetting>>[];
  final pending = <({void Function() succeed, void Function() fail})>[];
  final calls = <DashboardSection, int>{};

  Future<T> load<T>(DashboardSection section, T result) {
    calls.update(section, (value) => value + 1, ifAbsent: () => 1);
    if (section != target) return Future.value(result);
    final completer = Completer<T>();
    pending.add((
      succeed: () => completer.complete(result),
      fail: () => completer.completeError(StateError('source unavailable')),
    ));
    return completer.future;
  }

  @override
  Future<DashboardSetting> loadDashboardSetting({required String account}) {
    settingsReads++;
    if (!gateSettings) return Future.value(_setting());
    final completer = Completer<DashboardSetting>();
    settings.add(completer);
    onSettingsRead?.call();
    return completer.future;
  }

  @override
  Future<List<CalendarEvent>> loadTodayEvents(String account) =>
      load(DashboardSection.todaySchedule, <CalendarEvent>[]);
  @override
  Future<List<RecommendedEvent>> loadRecommendEvents(String city) =>
      load(DashboardSection.recommendEvents, <RecommendedEvent>[]);
  @override
  Future<List<RecommendedPlace>> loadRecommendPlaces(String city) =>
      load(DashboardSection.recommendPlaces, <RecommendedPlace>[]);
  @override
  Future<AccountingDashboardSummary> loadAccountingSummary({
    required String accountId,
  }) => load(
    DashboardSection.accounting,
    const AccountingDashboardSummary.empty(),
  );
  @override
  Future<PointDashboardSummary> loadPointSummary({required String accountId}) =>
      load(DashboardSection.points, const PointDashboardSummary.empty());
}

void main() {
  late _Repository repository;
  late ControllerDashboard controller;
  late ProviderLocale locale;
  setUp(() {
    repository = _Repository();
    locale = ProviderLocale(locale: const Locale('en'));
    controller = ControllerDashboard(
      repository: repository,
      localeProvider: locale,
    )..switchAccount('user');
  });
  tearDown(() {
    controller.dispose();
    locale.dispose();
  });

  for (final all in [true, false]) {
    test(
      'account change during batch start prevents all obsolete reads ($all)',
      () async {
        var changed = false;
        controller.addListener(() {
          if (!changed && controller.loading) {
            changed = true;
            controller.switchAccount('other');
          }
        });
        await (all
            ? controller.refreshAll(account: 'user')
            : controller.refreshCore(account: 'user'));
        expect(repository.calls, isEmpty);
        expect(repository.settingsReads, 0);
        expect(controller.loading, isFalse);
      },
    );
  }
  for (final changeAccount in [true, false]) {
    test(
      'settings waiter follows synchronous newer refresh (new account: $changeAccount)',
      () async {
        repository.gateSettings = true;
        Future<void>? newer;
        var started = false;
        final nextAccount = changeAccount ? 'other' : 'user';
        repository.onSettingsRead = () {
          if (started) return;
          started = true;
          if (changeAccount) controller.switchAccount(nextAccount);
          newer = controller.refreshCore(account: nextAccount);
        };
        final first = controller.refreshAll(account: 'user');
        expect(repository.settings.length, 2);
        var settingsReady = false;
        final waiting = controller
            .waitForSettings(account: nextAccount)
            .then((_) => settingsReady = true);
        repository.settings.first.complete(
          _setting().copyWith(recommendEventCity: 'old'),
        );
        await first;
        expect(settingsReady, isFalse);
        repository.settings.last.complete(
          _setting().copyWith(recommendEventCity: 'new'),
        );
        await newer;
        await waiting;
        expect(controller.setting.recommendEventCity, 'new');
        expect(settingsReady, isTrue);
        expect(controller.loading, isFalse);
      },
    );
  }

  for (final section in DashboardSection.values) {
    Future<void> refreshSection() => switch (section) {
      DashboardSection.todaySchedule => controller.refreshTodaySchedule(
        account: 'user',
      ),
      DashboardSection.recommendEvents => controller.refreshRecommendEvent(
        account: 'user',
      ),
      DashboardSection.recommendPlaces => controller.refreshRecommendPlace(
        account: 'user',
      ),
      DashboardSection.accounting => controller.refreshAccounting(
        accountId: 'cash',
      ),
      DashboardSection.points => controller.refreshPoints(accountId: 'points'),
    };

    test(
      '$section skips unsent read after account switch during publication',
      () async {
        var switched = false;
        controller.addListener(() {
          if (!switched && controller.isLoading(section)) {
            switched = true;
            controller.switchAccount('another');
          }
        });
        await refreshSection();
        expect(repository.calls[section] ?? 0, 0);
        expect(controller.loading, isFalse);
      },
    );

    test(
      '$section skips superseded read started by a synchronous listener',
      () async {
        Future<void>? newer;
        var started = false;
        controller.addListener(() {
          if (!started && controller.isLoading(section)) {
            started = true;
            newer = refreshSection();
          }
        });
        final first = refreshSection();
        await first;
        await newer;
        expect(repository.calls[section], 1);
        expect(controller.loading, isFalse);
      },
    );

    test(
      'refreshAll releases completed sections while $section remains pending',
      () async {
        repository.target = section;
        final pending = controller.refreshAll(account: 'user');
        await Future<void>.delayed(Duration.zero);
        for (final other in DashboardSection.values) {
          expect(
            controller.isLoading(other),
            other == section,
            reason: '$other',
          );
        }
        repository.pending.single.succeed();
        await pending;
        expect(controller.loading, false);
      },
    );
    test(
      'late $section failure cannot mark a newer successful refresh failed',
      () async {
        repository.target = section;
        final first = controller.refreshAll(account: 'user');
        await Future<void>.delayed(Duration.zero);
        final second = controller.refreshAll(account: 'user');
        await Future<void>.delayed(Duration.zero);
        expect(repository.pending.length, 2);
        repository.pending.last.succeed();
        await second;
        repository.pending.first.fail();
        await first;
        expect(controller.hasFailed(section), false);
        expect(controller.loading, false);
      },
    );
  }

  for (final section in [
    DashboardSection.todaySchedule,
    DashboardSection.accounting,
    DashboardSection.points,
  ]) {
    test(
      'refreshCore releases other summaries while $section is pending',
      () async {
        repository.target = section;
        final pending = controller.refreshCore(account: 'user');
        await Future<void>.delayed(Duration.zero);
        for (final other in [
          DashboardSection.todaySchedule,
          DashboardSection.accounting,
          DashboardSection.points,
        ]) {
          expect(controller.isLoading(other), other == section);
        }
        repository.pending.single.succeed();
        await pending;
        expect(controller.loading, false);
      },
    );
  }

  test('superseded settings do not launch obsolete section reads', () async {
    repository.gateSettings = true;
    final first = controller.refreshAll(account: 'user');
    final second = controller.refreshAll(account: 'user');
    repository.settings.last.complete(_setting());
    await second;
    repository.settings.first.complete(_setting());
    await first;
    expect(repository.calls[DashboardSection.todaySchedule], 2);
    for (final section in DashboardSection.values.skip(1)) {
      expect(repository.calls[section], 1, reason: '$section');
    }
    expect(controller.loading, false);
  });

  test(
    'current failures remain visible and a fresh retry can clear them',
    () async {
      repository.target = DashboardSection.recommendEvents;
      final first = controller.refreshAll(account: 'user');
      await Future<void>.delayed(Duration.zero);
      repository.pending.single.fail();
      await first;
      expect(controller.hasFailed(DashboardSection.recommendEvents), true);
      final retry = controller.retrySection(
        section: DashboardSection.recommendEvents,
        account: 'user',
      );
      repository.pending.last.succeed();
      await retry;
      expect(controller.hasFailed(DashboardSection.recommendEvents), false);
      expect(controller.loading, false);
    },
  );
}
