import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/pages/home/model/accounting/income_expense_item.dart';
import 'package:life_pilot/pages/home/model/point/point_record_item.dart';
import 'package:life_pilot/pages/home/model/dashboard/dashboard_setting.dart';
import 'package:life_pilot/pages/home/controller_dashboard.dart';
import 'package:life_pilot/pages/home/model/event/calendar_event.dart';
import 'package:life_pilot/pages/home/model/event/recommended_event.dart';
import 'package:life_pilot/pages/home/model/place/recommended_place.dart';
import 'package:life_pilot/pages/home/repository/repository_dashboard.dart';
import 'package:life_pilot/utils/provider_locale.dart';

class _Repository extends DashboardRepository {
  final schedules = <Completer<List<CalendarEvent>>>[];
  @override
  Future<List<CalendarEvent>> loadTodayEvents(String account) {
    final pending = Completer<List<CalendarEvent>>();
    schedules.add(pending);
    return pending.future;
  }

  @override
  Future<DashboardSetting> loadDashboardSetting({
    required String account,
  }) async => DashboardSetting(
    recommendEventCity: '',
    recommendPlaceCity: '',
    language: 'en',
  );
  @override
  Future<List<RecommendedEvent>> loadRecommendEvents(String city) async => [];
  @override
  Future<List<RecommendedPlace>> loadRecommendPlaces(String city) async => [];
  @override
  Future<AccountingDashboardSummary> loadAccountingSummary({
    required String accountId,
  }) async => const AccountingDashboardSummary.empty();
  @override
  Future<PointDashboardSummary> loadPointSummary({
    required String accountId,
  }) async => const PointDashboardSummary.empty();
  @override
  Future<void> completeEvent({
    required String id,
    required String account,
  }) async {}
}

void main() {
  for (final entry in ['all', 'core', 'schedule']) {
    group(entry, () {
      late _Repository repository;
      late ControllerDashboard model;
      late ProviderLocale locale;
      Future<void> load() => switch (entry) {
        'all' => model.refreshAll(account: 'user'),
        'core' => model.refreshCore(account: 'user'),
        _ => model.refreshTodaySchedule(account: 'user'),
      };
      setUp(() {
        repository = _Repository();
        locale = ProviderLocale(locale: const Locale('en'));
        model = ControllerDashboard(
          repository: repository,
          localeProvider: locale,
        )..switchAccount('user');
      });
      tearDown(() {
        if (!model.notifierDisposed) model.dispose();
        locale.dispose();
      });

      test('older schedule cannot overwrite the latest refresh', () async {
        final old = load();
        final fresh = model.refreshTodaySchedule(account: 'user');
        repository.schedules[1].complete([
          CalendarEvent(id: 'new', name: 'new'),
        ]);
        await fresh;
        repository.schedules[0].complete([
          CalendarEvent(id: 'old', name: 'old'),
        ]);
        await old;
        expect(model.state.todayEvents.single.id, 'new');
      });

      test('wrong-account calls cannot invalidate an active request', () async {
        final pending = load();
        await model.refreshAll(account: 'wrong');
        await model.refreshCore(account: 'wrong');
        expect(repository.schedules.length, 1);
        repository.schedules.single.complete([
          CalendarEvent(id: 'valid', name: 'valid'),
        ]);
        await pending;
        expect(model.state.todayEvents.single.id, 'valid');
      });

      test('confirmed completion is not undone by a stale response', () async {
        final old = load();
        await model.completeEvent(id: 'done', account: 'user');
        repository.schedules.single.complete([
          CalendarEvent(id: 'done', name: 'done'),
        ]);
        await old;
        expect(model.state.todayEvents, isEmpty);
      });

      test('new calendar item survives a pending old response', () async {
        final old = load();
        final now = DateTime(2026, 10, 20, 12);
        model.addUpcomingEvent(
          CalendarEvent(id: 'added', name: 'added', startDate: now),
          account: 'user',
          currentTime: now,
        );
        repository.schedules.single.complete([]);
        await old;
        expect(model.state.todayEvents.single.id, 'added');
      });
      if (entry != 'schedule') {
        test(
          'old-account failure does not mark new sections as failed',
          () async {
            final old = load();
            model.switchAccount('new');
            repository.schedules.single.completeError(
              StateError('old request failed'),
            );
            await old;
            expect(model.hasFailed(DashboardSection.todaySchedule), false);
            expect(model.state.todayEvents, isEmpty);
          },
        );
      }
    });
  }
}
