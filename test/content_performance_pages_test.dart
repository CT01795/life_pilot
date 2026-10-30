import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/event/controller_content_performance.dart';
import 'package:life_pilot/event/model_content_performance.dart';
import 'package:life_pilot/event/model_content_performance_period.dart';
import 'content_performance_and_event_dates_test.dart'
    show PerformanceTestService;
import 'record_statistics_test.dart' show StatisticsTestAuth;

ModelContentPerformance _page(String id, {int? next = 20}) =>
    ModelContentPerformance.fromPage({
      'items': [
        {'id': id, 'name': id, 'page_views': 2},
      ],
      'totals': {'page_views': 100},
      'next_offset': next,
    }, attractions: false);

class _PagedService extends PerformanceTestService {
  final more = <Completer<ModelContentPerformance?>>[];
  final offsets = <int>[];
  @override
  Future<ModelContentPerformance?> readNextPage({
    required String owner,
    required bool attractions,
    required ContentPerformancePeriod period,
    required String keyword,
    required int offset,
    bool Function()? shouldContinue,
  }) {
    offsets.add(offset);
    final pending = Completer<ModelContentPerformance?>();
    more.add(pending);
    return pending.future;
  }
}

void main() {
  test(
    'later pages retain first-query totals without re-aggregating the whole result',
    () {
      final later = ModelContentPerformance.fromPage({
        'items': [
          {'id': 'second', 'page_views': 3},
        ],
        'totals': null,
        'next_offset': null,
      }, attractions: false);
      final result = _page('first').appendPage(later);
      expect(result.totalFor(ContentPerformanceMetric.pageViews), 100);
      expect(result.items, hasLength(2));
      expect(result.hasMore, false);
    },
  );
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'failed next page preserves cards, totals and continuation; retry appends without summing totals twice',
    () async {
      final auth = StatisticsTestAuth(), service = _PagedService();
      final controller = ControllerContentPerformance(
        auth: auth,
        attractions: false,
        service: service,
      );
      try {
        final initial = controller.load();
        service.pending.single.complete(_page('first'));
        await initial;
        final next = controller.loadMore();
        await controller.loadMore();
        expect(service.more, hasLength(1));
        service.more[0].completeError(StateError('offline'));
        await next;
        expect(controller.data!.items.single.id, 'first');
        expect(controller.data!.hasMore, true);
        expect(controller.moreError, isNotNull);
        final retry = controller.loadMore();
        service.more[1].complete(_page('second', next: null));
        await retry;
        expect(controller.data!.items.map((e) => e.id), ['first', 'second']);
        expect(
          controller.data!.totalFor(ContentPerformanceMetric.pageViews),
          100,
        );
        expect(controller.data!.hasMore, false);
        expect(controller.moreError, isNull);
        expect(service.offsets, [20, 20]);
      } finally {
        controller.dispose();
        auth.dispose();
      }
    },
  );
  test('search change discards an older in-flight next page', () async {
    final auth = StatisticsTestAuth(), service = _PagedService();
    final controller = ControllerContentPerformance(
      auth: auth,
      attractions: false,
      service: service,
    );
    try {
      final initial = controller.load();
      service.pending.single.complete(_page('old'));
      await initial;
      final next = controller.loadMore();
      final search = controller.search('new');
      service.pending[1].complete(_page('new', next: null));
      await search;
      service.more.single.complete(_page('stale', next: null));
      await next;
      expect(controller.data!.items.single.id, 'new');
      expect(controller.loadingMore, false);
    } finally {
      controller.dispose();
      auth.dispose();
    }
  });
  test(
    'account change clears loaded pages and ignores their late continuation',
    () async {
      final auth = StatisticsTestAuth(), service = _PagedService();
      final controller = ControllerContentPerformance(
        auth: auth,
        attractions: false,
        service: service,
      );
      try {
        final initial = controller.load();
        service.pending.single.complete(_page('old'));
        await initial;
        final next = controller.loadMore();
        auth.change(account: 'other@example.com');
        service.more.single.complete(_page('stale', next: null));
        await next;
        expect(controller.data, isNull);
        expect(controller.loadingMore, false);
      } finally {
        controller.dispose();
        auth.dispose();
      }
    },
  );
  test(
    'overlapping pages do not duplicate cards or change the global denominator',
    () {
      final result = _page('same').appendPage(_page('same', next: null));
      expect(result.items, hasLength(1));
      expect(result.totalFor(ContentPerformanceMetric.pageViews), 100);
      expect(
        result.shareFor(
          result.items.single,
          ContentPerformanceMetric.pageViews,
        ),
        .02,
      );
    },
  );
}
