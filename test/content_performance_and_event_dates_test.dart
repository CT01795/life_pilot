import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/event/controller_content_performance.dart';
import 'package:life_pilot/event/controller_page_event_add.dart';
import 'package:life_pilot/event/model_content_performance.dart';
import 'package:life_pilot/event/model_content_performance_period.dart';
import 'package:life_pilot/event/model_event_item.dart';
import 'package:life_pilot/event/service_content_performance.dart';
import 'package:life_pilot/utils/const.dart';
import 'record_statistics_test.dart' show StatisticsTestAuth;

class PerformanceTestService extends ServiceContentPerformance {
  final pending = <Completer<ModelContentPerformance>>[];
  final owners = <String>[];
  final kinds = <bool>[];
  final periods = <ContentPerformancePeriod?>[];
  final keywords = <String>[];
  final statisticsOnlyRequests = <bool>[];
  final activeRequests = <bool Function()?>[];
  @override
  Future<ModelContentPerformance> read({
    required String owner,
    required bool attractions,
    bool includeSubmissionDetails = false,
    ContentPerformancePeriod? period,
    String keyword = '',
    bool statisticsOnly = false,
    bool Function()? shouldContinue,
  }) {
    owners.add(owner);
    kinds.add(attractions);
    periods.add(period);
    keywords.add(keyword);
    statisticsOnlyRequests.add(statisticsOnly);
    activeRequests.add(shouldContinue);
    final result = Completer<ModelContentPerformance>();
    pending.add(result);
    return result.future;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'performance totals include all six counters and tolerate null/string values',
    () {
      final result = ModelContentPerformance([
        {'page_views': 10, 'card_clicks': '3', 'saves': 2, 'like_counts': 1},
        {'page_views': 4, 'registration_clicks': 7, 'dislike_counts': 2},
      ]);
      expect(result.totals, {
        'page_views': 14,
        'card_clicks': 3,
        'registration_clicks': 7,
        'saves': 2,
        'like_counts': 1,
        'dislike_counts': 2,
      });
    },
  );
  for (final attractions in [false, true]) {
    group(attractions ? 'attraction performance' : 'activity performance', () {
      late StatisticsTestAuth auth;
      late PerformanceTestService service;
      late ControllerContentPerformance controller;
      setUp(() {
        auth = StatisticsTestAuth();
        service = PerformanceTestService();
        controller = ControllerContentPerformance(
          auth: auth,
          attractions: attractions,
          service: service,
        );
      });
      tearDown(() {
        if (!controller.notifierDisposed) controller.dispose();
        for (final pending in service.pending) {
          if (!pending.isCompleted) {
            pending.complete(ModelContentPerformance([]));
          }
        }
        auth.dispose();
      });
      test(
        'requests only current author and the matching content type',
        () async {
          final pending = controller.load();
          expect(service.owners, ['one@example.com']);
          expect(service.kinds, [attractions]);
          service.pending.single.complete(
            ModelContentPerformance([
              {'name': 'mine'},
            ]),
          );
          await pending;
          expect(controller.data!.rows.single['name'], 'mine');
        },
      );
      test(
        'switching author clears results and refuses stale response',
        () async {
          final pending = controller.load();
          auth.change(account: 'two@example.com');
          service.pending.single.complete(
            ModelContentPerformance([
              {'name': 'old'},
            ]),
          );
          await pending;
          expect(controller.data, null);
          await controller.load();
          expect(service.pending.length, 1);
        },
      );
      test('dispose ignores response', () async {
        final pending = controller.load();
        expect(service.activeRequests.single!(), true);
        controller.dispose();
        expect(service.activeRequests.single!(), false);
        service.pending.single.complete(ModelContentPerformance([]));
        await pending;
        expect(controller.data, null);
      });
      test(
        'changing search and month invalidates old pagination predicates',
        () async {
          final first = controller.load();
          final second = controller.search('new');
          expect(service.activeRequests[0]!(), false);
          expect(service.activeRequests[1]!(), true);
          final third = controller.selectMonth(DateTime(2026, 7));
          expect(service.activeRequests[1]!(), false);
          expect(service.activeRequests[2]!(), true);
          for (final pending in service.pending) {
            pending.complete(ModelContentPerformance([]));
          }
          await Future.wait([first, second, third]);
          expect(service.activeRequests.every((active) => !active!()), true);
        },
      );
      test(
        'timeout closes the pagination predicate before a late HTTP result',
        () async {
          controller.dispose();
          controller = ControllerContentPerformance(
            auth: auth,
            attractions: attractions,
            service: service,
            requestTimeout: const Duration(milliseconds: 5),
          );
          await controller.load();
          expect(controller.error, isA<TimeoutException>());
          expect(service.activeRequests.single!(), false);
          service.pending.single.complete(
            ModelContentPerformance([
              {'name': 'late'},
            ]),
          );
          await Future<void>.delayed(Duration.zero);
          expect(controller.data, null);
        },
      );
      test('failure provides retry state', () async {
        final pending = controller.load();
        service.pending.single.completeError(StateError('offline'));
        await pending;
        expect(controller.error, isA<StateError>());
        expect(controller.loading, false);
      });
      test(
        'repeated searches with the same filters share the active request',
        () async {
          final first = controller.search('Taipei');
          final others = List.generate(8, (_) => controller.search('Taipei'));
          expect(service.pending.length, 1);
          service.pending.single.complete(ModelContentPerformance([]));
          await Future.wait([first, ...others]);
          final fresh = controller.search('Taipei');
          expect(service.pending.length, 2);
          service.pending.last.complete(ModelContentPerformance([]));
          await fresh;
        },
      );
      test(
        'queued forced refresh cannot resurrect a previous author after switching',
        () async {
          final first = controller.load();
          final forced = controller.load(force: true);
          auth.change(account: 'two@example.com');
          service.pending.single.complete(
            ModelContentPerformance([
              {'name': 'old'},
            ]),
          );
          await Future.wait([first, forced]);
          expect(service.pending.length, 1);
          expect(controller.data, null);
        },
      );
    });
  }
  group('new and edited event date validation', () {
    late StatisticsTestAuth auth;
    late ControllerPageEventAdd controller;
    setUp(() {
      auth = StatisticsTestAuth();
      controller = ControllerPageEventAdd(
        auth: auth,
        tableName: TableNames.recommendEvents,
      );
    });
    tearDown(() {
      controller.dispose();
      auth.dispose();
    });
    test(
      'earlier end date remains selected and is rejected, not silently clamped',
      () {
        controller.setDate(DateTime(2026, 10, 20), isStart: true);
        controller.setDate(DateTime(2026, 10, 19), isStart: false);
        expect(controller.endDate, DateTime(2026, 10, 19));
        expect(controller.hasInvalidDateRange(), true);
        expect(controller.hasInvalidDates, true);
      },
    );
    test('changing start date after existing end is also detected', () {
      controller.setDate(DateTime(2026, 10, 19), isStart: false);
      controller.setDate(DateTime(2026, 10, 20), isStart: true);
      expect(controller.hasInvalidDates, true);
      controller.setDate(DateTime(2026, 10, 21), isStart: false);
      expect(controller.hasInvalidDates, false);
    });
    test('same calendar day is allowed regardless of stored hours', () {
      controller.setDate(DateTime(2026, 10, 19, 20), isStart: true);
      controller.setDate(DateTime(2026, 10, 19, 1), isStart: false);
      expect(controller.hasInvalidDates, false);
    });
    test('no end date is valid', () {
      controller.endDate = null;
      expect(controller.hasInvalidDates, false);
    });
    test('invalid sub-event prevents saving the whole event', () {
      controller.startDate = DateTime(2026, 10, 19);
      controller.endDate = DateTime(2026, 10, 20);
      controller.subEvents.add(
        EventItem(
          id: 's',
          name: 's',
          startDate: DateTime(2026, 10, 19),
          endDate: DateTime(2026, 10, 20),
        ),
      );
      controller.setDate(DateTime(2026, 10, 18), isStart: false, index: 0);
      expect(controller.hasInvalidDateRange(), false);
      expect(controller.hasInvalidDateRange(index: 0), true);
      expect(controller.hasInvalidDates, true);
    });
  });
}
