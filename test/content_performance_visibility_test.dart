import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/event/controller_content_performance.dart';
import 'package:life_pilot/event/model_content_performance.dart';
import 'record_statistics_test.dart' show StatisticsTestAuth;
import 'content_performance_and_event_dates_test.dart'
    show PerformanceTestService;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'statistics-only mode hides null/missing/zero counters but retains any nonzero metric',
    () {
      final rows = <Map<String, dynamic>>[
        {'id': 'missing'},
        {
          'id': 'zeros',
          for (final column in contentPerformanceColumns) column: 0,
        },
        {
          'id': 'nulls',
          for (final column in contentPerformanceColumns) column: null,
        },
        for (final column in contentPerformanceColumns)
          {'id': column, column: 1},
      ];
      final model = ModelContentPerformance(rows, statisticsOnly: true);
      expect(model.items.map((item) => item.id), contentPerformanceColumns);
      expect(model.totals.values.every((value) => value == 1), true);
      expect(
        ModelContentPerformance(rows).items.length,
        9,
      ); // Vendor metadata overview stays complete.
    },
  );
  test(
    'activity and attraction sorts differ after the same nearest expiry date',
    () {
      final rows = <Map<String, dynamic>>[
        {
          'id': 'A-early',
          'city': 'A',
          'end_date': '2026-07-31',
          'start_date': '2026-01-05',
        },
        {
          'id': 'A-late',
          'city': 'A',
          'end_date': '2026-07-31',
          'start_date': '2026-01-25',
        },
        {
          'id': 'B',
          'city': 'B',
          'end_date': '2026-07-31',
          'start_date': '2026-01-30',
        },
        {
          'id': 'nearest',
          'city': 'Z',
          'end_date': '2026-07-01',
          'start_date': '2026-01-20',
        },
        {'id': 'undated'},
      ];
      expect(
        ModelContentPerformance(
          rows,
          sortByExpiry: true,
        ).items.map((item) => item.id),
        ['nearest', 'A-late', 'A-early', 'B', 'undated'],
      );
      expect(
        ModelContentPerformance(
          rows,
          sortByExpiry: true,
          attractions: true,
        ).items.map((item) => item.id),
        ['nearest', 'A-early', 'A-late', 'B', 'undated'],
      );
    },
  );
  test(
    'a hanging New Taipei search stops loading, can retry, and ignores the late first response',
    () async {
      final auth = StatisticsTestAuth();
      final service = PerformanceTestService();
      final controller = ControllerContentPerformance(
        auth: auth,
        attractions: false,
        service: service,
        requestTimeout: const Duration(milliseconds: 20),
      );
      await controller.search('新北');
      expect(service.keywords.single, '新北');
      expect(service.statisticsOnlyRequests.single, true);
      expect(controller.loading, false);
      expect(controller.error, isA<TimeoutException>());
      final retry = controller.load();
      service.pending[1].complete(
        ModelContentPerformance([
          {'name': 'new', 'page_views': 1},
        ]),
      );
      await retry;
      service.pending[0].complete(
        ModelContentPerformance([
          {'name': 'old', 'page_views': 1},
        ]),
      );
      await Future<void>.delayed(Duration.zero);
      expect(controller.error, null);
      expect(controller.loading, false);
      expect(controller.data!.items.single.name, 'new');
      controller.dispose();
      auth.dispose();
    },
  );
}
