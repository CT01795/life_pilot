import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/event/controller_content_performance.dart';
import 'package:life_pilot/event/model_content_performance.dart';
import 'package:life_pilot/record_statistics/controller_record_statistics.dart';
import 'package:life_pilot/record_statistics/model_record_statistics.dart';

import 'content_performance_and_event_dates_test.dart'
    show PerformanceTestService;
import 'record_statistics_test.dart'
    show StatisticsTestAuth, StatisticsTestService;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final kind in RecordStatisticsKind.values) {
    test(
      '$kind clears on sign-out and reloads on sign-in to the original account',
      () async {
        final auth = StatisticsTestAuth();
        final service = StatisticsTestService();
        final c = ControllerRecordStatistics(
          auth: auth,
          accountId: 'a',
          kind: kind,
          service: service,
        );
        addTearDown(() {
          c.dispose();
          auth.dispose();
        });
        final first = c.load();
        service.finish(0);
        await first;
        expect(c.data, isNotNull);
        auth.owner = null;
        auth.notifyListeners();
        expect(c.data, isNull);
        expect(c.loading, isFalse);
        await c.load();
        expect(service.reads, hasLength(1));
        auth.change(account: 'one@example.com');
        expect(service.reads, hasLength(2));
        final fresh = c.load();
        service.finish(1, total: 222);
        await fresh;
        expect(c.data!.total, 222);
      },
    );
  }

  for (final attractions in [false, true]) {
    test(
      'performance attractions=$attractions reloads after sign-out and sign-in',
      () async {
        final auth = StatisticsTestAuth();
        final service = PerformanceTestService();
        final c = ControllerContentPerformance(
          auth: auth,
          attractions: attractions,
          service: service,
        );
        addTearDown(() {
          c.dispose();
          auth.dispose();
        });
        final first = c.load();
        service.pending[0].complete(ModelContentPerformance([]));
        await first;
        auth.owner = null;
        auth.notifyListeners();
        expect(c.data, isNull);
        expect(c.loading, isFalse);
        await c.load();
        expect(service.pending, hasLength(1));
        auth.change(account: 'one@example.com');
        expect(service.pending, hasLength(2));
        final fresh = c.load();
        final result = ModelContentPerformance([
          {'id': 'fresh', 'page_views': 2},
        ]);
        service.pending[1].complete(result);
        await fresh;
        expect(c.data, same(result));
      },
    );
  }

  for (final kind in RecordStatisticsKind.values) {
    for (final history in [false, true]) {
      for (final oldFailure in [false, true]) {
        test(
          '$kind history=$history reloads after A-B-A and ignores old result (failure=$oldFailure)',
          () async {
            final auth = StatisticsTestAuth();
            final service = StatisticsTestService();
            final c = ControllerRecordStatistics(
              auth: auth,
              accountId: 'a',
              kind: kind,
              history: history,
              service: service,
            );
            addTearDown(() {
              c.dispose();
              auth.dispose();
            });
            final old = c.load();
            auth.change(account: 'two@example.com');
            expect(c.data, isNull);
            expect(c.loading, isFalse);
            var notifications = 0;
            c.addListener(() => notifications++);
            for (var i = 0; i < 4; i++) {
              auth.notifyListeners();
            }
            expect(notifications, 0);
            await c.load();
            expect(service.reads, hasLength(1));
            expect(service.activeRequests.first!(), isFalse);

            auth.change(account: 'one@example.com');
            expect(c.loading, isTrue);
            expect(service.reads, hasLength(2));
            final fresh = c.load();
            expect(service.reads, hasLength(2));
            service.finish(1, total: 222);
            await fresh;
            final current = c.data;
            expect(current!.total, history ? 5 : 222);
            if (oldFailure) {
              service.reads[0].completeError(StateError('obsolete'));
            } else {
              service.reads[0].complete([
                {'date': DateTime.now(), 'value': 999},
              ]);
            }
            if (service.totals.isNotEmpty) service.totals[0].complete(999);
            await old;
            expect(c.data, same(current));
            expect(c.error, isNull);
            expect(c.loading, isFalse);
            expect(service.scopes.map((s) => s.$1), [
              'one@example.com',
              'one@example.com',
            ]);
          },
        );
      }
    }
  }

  for (final attractions in [false, true]) {
    for (final oldFailure in [false, true]) {
      test(
        'performance attractions=$attractions reloads after A-B-A (old failure=$oldFailure)',
        () async {
          final auth = StatisticsTestAuth();
          final service = PerformanceTestService();
          final c = ControllerContentPerformance(
            auth: auth,
            attractions: attractions,
            service: service,
          );
          addTearDown(() {
            c.dispose();
            auth.dispose();
          });
          final old = c.load();
          auth.change(account: 'two@example.com');
          var notifications = 0;
          c.addListener(() => notifications++);
          for (var i = 0; i < 4; i++) {
            auth.notifyListeners();
          }
          expect(notifications, 0);
          await c.load();
          expect(service.pending, hasLength(1));
          expect(service.activeRequests.first!(), isFalse);
          auth.change(account: 'one@example.com');
          expect(service.pending, hasLength(2));
          expect(c.loading, isTrue);
          final fresh = c.load();
          final result = ModelContentPerformance([
            {'id': 'current', 'name': 'Current', 'page_views': 2},
          ]);
          service.pending[1].complete(result);
          await fresh;
          if (oldFailure) {
            service.pending[0].completeError(StateError('obsolete'));
          } else {
            service.pending[0].complete(
              ModelContentPerformance([
                {'id': 'obsolete', 'name': 'Old', 'page_views': 999},
              ]),
            );
          }
          await old;
          expect(c.data, same(result));
          expect(c.error, isNull);
          expect(c.loading, isFalse);
          expect(service.owners, ['one@example.com', 'one@example.com']);
          expect(service.kinds, [attractions, attractions]);
        },
      );
    }
  }
}
