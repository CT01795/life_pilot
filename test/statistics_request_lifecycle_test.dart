import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/event/controller_content_performance.dart';
import 'package:life_pilot/event/model_content_performance.dart';
import 'package:life_pilot/record_statistics/controller_record_statistics.dart';
import 'package:life_pilot/record_statistics/model_record_statistics.dart';
import 'record_statistics_test.dart'
    show StatisticsTestAuth, StatisticsTestService;
import 'content_performance_and_event_dates_test.dart'
    show PerformanceTestService;

class _RevisionAuth extends StatisticsTestAuth {
  int revision = 0;
  @override
  int get personalDataRevision => revision;

  void cleanup() {
    revision++;
    notifyListeners();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final kind in RecordStatisticsKind.values) {
    for (final history in [false, true]) {
      test(
        '$kind history=$history: timeout allows retry and ignores late failure',
        () async {
          final auth = _RevisionAuth();
          final service = StatisticsTestService();
          final controller = ControllerRecordStatistics(
            auth: auth,
            accountId: 'account',
            kind: kind,
            history: history,
            service: service,
            requestTimeout: const Duration(milliseconds: 20),
          );
          addTearDown(() {
            if (!controller.notifierDisposed) controller.dispose();
            auth.dispose();
          });
          await controller.load();
          expect(controller.loading, false);
          expect(controller.error, isA<TimeoutException>());
          final retry = controller.load();
          service.finish(1, total: 222);
          await retry;
          expect(controller.error, isNull);
          expect(controller.data!.total, history ? 5 : 222);
          service.reads[0].completeError(StateError('late offline response'));
          if (service.totals.isNotEmpty) service.totals[0].complete(999);
          await Future<void>.delayed(Duration.zero);
          expect(controller.error, isNull);
          expect(controller.data!.total, history ? 5 : 222);
        },
      );
    }

    for (final queued in [false, true]) {
      test('$kind: cleanup replaces in-flight work, queued=$queued', () async {
        final auth = _RevisionAuth();
        final service = StatisticsTestService();
        final controller = ControllerRecordStatistics(
          auth: auth,
          accountId: 'account',
          kind: kind,
          service: service,
        );
        addTearDown(() {
          if (!controller.notifierDisposed) controller.dispose();
          auth.dispose();
        });
        final old = controller.load();
        final forced = queued
            ? controller.load(force: true)
            : Future<void>.value();
        auth.cleanup();
        expect(service.reads.length, 2);
        expect(controller.data, isNull);
        service.finish(1, total: 222);
        await Future<void>.delayed(Duration.zero);
        expect(controller.data!.total, 222);
        service.finish(0, total: 999);
        await Future.wait([old, forced]);
        expect(service.reads.length, 2);
        expect(controller.data!.total, 222);
      });
    }

    test(
      '$kind: ordinary auth notifications do not reload; cleanup does',
      () async {
        final auth = _RevisionAuth();
        final service = StatisticsTestService();
        final controller = ControllerRecordStatistics(
          auth: auth,
          accountId: 'account',
          kind: kind,
          service: service,
        );
        addTearDown(() {
          if (!controller.notifierDisposed) controller.dispose();
          auth.dispose();
        });
        final first = controller.load();
        auth.notifyListeners();
        expect(service.reads.length, 1);
        service.finish(0);
        await first;
        auth.notifyListeners();
        expect(service.reads.length, 1);
        auth.cleanup();
        expect(controller.data, isNull);
        expect(controller.loading, true);
        service.reads[1].complete([]);
        service.totals[1].complete(0);
        await Future<void>.delayed(Duration.zero);
        expect(controller.data!.hasChartData, false);
        expect(controller.data!.total, 0);
        controller.dispose();
        auth.cleanup();
        expect(service.reads.length, 2);
      },
    );
  }

  for (final attractions in [false, true]) {
    for (final queued in [false, true]) {
      test(
        'attractions=$attractions: cleanup keeps filters and rejects stale work, queued=$queued',
        () async {
          final auth = _RevisionAuth();
          final service = PerformanceTestService();
          final controller =
              ControllerContentPerformance(
                  auth: auth,
                  attractions: attractions,
                  service: service,
                )
                ..selectedMonth = DateTime(2026, 7)
                ..keyword = '新北';
          addTearDown(() {
            if (!controller.notifierDisposed) controller.dispose();
            auth.dispose();
          });
          final old = controller.load();
          final forced = queued
              ? controller.load(force: true)
              : Future<void>.value();
          auth.cleanup();
          expect(service.pending.length, 2);
          expect(service.keywords, ['新北', '新北']);
          expect(service.periods.last!.month, DateTime(2026, 7));
          expect(service.kinds, [attractions, attractions]);
          service.pending[1].complete(
            ModelContentPerformance([
              {'id': 'new', 'name': 'New', 'saves': 2},
            ]),
          );
          await Future<void>.delayed(Duration.zero);
          service.pending[0].complete(
            ModelContentPerformance([
              {'id': 'old', 'name': 'Old', 'saves': 999},
            ]),
          );
          await Future.wait([old, forced]);
          expect(service.pending.length, 2);
          expect(controller.data!.items.single.name, 'New');
        },
      );
    }
    test(
      'attractions=$attractions: cleanup refreshes loaded data but quota notifications do not',
      () async {
        final auth = _RevisionAuth();
        final service = PerformanceTestService();
        final controller = ControllerContentPerformance(
          auth: auth,
          attractions: attractions,
          service: service,
        );
        addTearDown(() {
          if (!controller.notifierDisposed) controller.dispose();
          auth.dispose();
        });
        final first = controller.load();
        service.pending[0].complete(
          ModelContentPerformance([
            {'id': 'old', 'saves': 7},
          ]),
        );
        await first;
        auth.notifyListeners();
        expect(service.pending.length, 1);
        auth.cleanup();
        expect(controller.data, isNull);
        expect(controller.loading, true);
        service.pending[1].complete(ModelContentPerformance([]));
        await Future<void>.delayed(Duration.zero);
        expect(controller.data!.items, isEmpty);
        controller.dispose();
        auth.cleanup();
        expect(service.pending.length, 2);
      },
    );
  }
}
