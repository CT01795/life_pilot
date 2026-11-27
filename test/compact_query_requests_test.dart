import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:life_pilot/utils/supabase.dart';
import 'package:life_pilot/vendor/service_vendor_account.dart';
import 'package:life_pilot/vendor/repository_vendor_dashboard_cache.dart';
import 'package:life_pilot/event/service_content_performance.dart';
import 'package:life_pilot/event/model_content_performance_period.dart';
import 'package:life_pilot/event/model_content_performance.dart';
import 'package:life_pilot/record_statistics/service_record_statistics.dart';
import 'package:life_pilot/record_statistics/model_record_statistics.dart';
import 'package:life_pilot/local_storage/local_data_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SupabaseClient client;
  late List<http.Request> requests;
  dynamic response;
  Completer<void>? gate;
  var status = 200;
  setUp(() async {
    requests = [];
    status = 200;
    gate = null;
    client = SupabaseClient(
      'https://example.supabase.co',
      'test-key',
      httpClient: MockClient((request) async {
        requests.add(request);
        final body = jsonEncode(response);
        final code = status;
        final pending = gate;
        if (pending != null) await pending.future;
        return http.Response(
          body,
          code,
          request: request,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    supabase = client;
    await client.auth.setInitialSession(
      jsonEncode({
        'access_token': 'test-token',
        'token_type': 'bearer',
        'user': {
          'id': 'owner',
          'email': 'one@example.com',
          'app_metadata': {},
          'user_metadata': {},
          'aud': 'authenticated',
          'created_at': '2026-01-01T00:00:00Z',
        },
      }),
    );
  });
  tearDown(() => client.dispose());
  test('obsolete workbench response cannot repopulate the cache', () async {
    response = {
      'status': {
        'plan': {'plan_code': 'free'},
        'status': 'active',
      },
      'metrics': {
        'published': 0,
        'pending': 0,
        'recent_submissions': [],
        'totals': <String, int>{},
      },
      'plans': [],
    };
    final service = ServiceVendorAccount();
    final initial = await service.fetchDashboard('one@example.com');
    final pending = gate = Completer<void>();
    final obsolete = service.fetchDashboard('one@example.com', force: true);
    await Future<void>.delayed(Duration.zero);
    expect(requests, hasLength(2));
    final updated = initial.withRecentSubmissions([]);
    service.cacheDashboard(updated);
    gate = null;
    pending.complete();
    expect(await obsolete, same(updated));
    expect(RepositoryVendorDashboardCache(client).read(), same(updated));
  });
  test('changed performance snapshot cannot be appended to old totals', () {
    ModelContentPerformance page(String version) =>
        ModelContentPerformance.fromPage({
          'items': [],
          'totals': {'page_views': 12},
          'snapshot_version': version,
        }, attractions: false);
    expect(page('a').appendPage(page('a')).snapshotVersion, 'a');
    expect(() => page('a').appendPage(page('b')), throwsStateError);
  });
  for (final attractions in [false, true]) {
    test(
      'empty performance page without totals is not an error ($attractions)',
      () async {
        response = {'items': [], 'totals': null, 'next_offset': null};
        final result = await ServiceContentPerformance().read(
          owner: 'one@example.com',
          attractions: attractions,

          period: ContentPerformancePeriod(now: DateTime(2026, 11, 4)),
        );
        expect(result.items, isEmpty);
        expect(result.hasMore, isFalse);
        expect(requests, hasLength(1));
      },
    );
  }
  test('missing performance page never reads raw recommendations', () async {
    status = 404;
    response = {'code': 'PGRST202', 'message': 'missing'};
    await expectLater(
      ServiceContentPerformance().read(
        owner: 'one@example.com',
        attractions: true,

        period: ContentPerformancePeriod(now: DateTime(2026, 11, 4)),
      ),
      throwsA(
        isA<PostgrestException>().having((e) => e.code, 'code', 'PGRST202'),
      ),
    );
    expect(
      requests.single.url.pathSegments.last,
      'get_my_content_performance_page',
    );
  });
  test('missing dashboard and chart RPCs never download raw detail', () async {
    status = 404;
    response = {'code': 'PGRST202', 'message': 'missing'};
    final missing = throwsA(
      isA<PostgrestException>().having((e) => e.code, 'code', 'PGRST202'),
    );
    await expectLater(
      ServiceVendorAccount().fetchDashboard('one@example.com'),
      missing,
    );
    await expectLater(
      ServiceRecordStatistics().read(
        owner: 'one@example.com',
        storage: DataStorageLocation.cloud,
        accountId: 'a',
        kind: RecordStatisticsKind.accounting,
        now: DateTime(2026, 10),
        history: true,
      ),
      missing,
    );
    expect(requests.map((r) => r.url.pathSegments.last), [
      'get_my_vendor_dashboard_bootstrap',
      'get_my_record_statistics',
    ]);
  });
  test(
    'vendor dashboard retrieves totals and five previews in one request',
    () async {
      response = {
        'status': {
          'plan': {'plan_code': 'free'},
          'status': 'active',
          'event_used': 10000,
          'attraction_used': 0,
          'image_bytes_used': 0,
        },
        'metrics': {
          'published': 10000,
          'pending': 0,
          'active_events': 10000,
          'active_attractions': 0,
          'totals': {'page_views': 123456},
          'recent_submissions': [],
        },
        'plans': [],
      };
      final result = await ServiceVendorAccount().fetchDashboard(
        'one@example.com',
      );
      expect(requests, hasLength(1));
      expect(
        requests.single.url.path,
        endsWith('/get_my_vendor_dashboard_bootstrap'),
      );
      expect(
        result.metrics.performance.totalFor(ContentPerformanceMetric.pageViews),
        123456,
      );
      final cached = await ServiceVendorAccount().fetchDashboard(
        'one@example.com',
      );
      expect(cached, same(result));
      expect(requests, hasLength(1));
      expect(jsonDecode(requests.single.body)['p_force_refresh'], false);
      expect(jsonDecode(requests.single.body)['p_include_plans'], true);

      response = [
        {
          'id': 'recent',
          'name': 'Recent event',
          'city': 'Taipei',
          'is_activity': true,
          'is_approved': false,
        },
      ];
      final cache = RepositoryVendorDashboardCache(client);
      await Future.wait([
        cache.refreshRecentSubmissions(),
        cache.refreshRecentSubmissions(),
      ]);
      expect(requests, hasLength(2));
      expect(
        requests.last.url.path,
        endsWith('/get_my_vendor_recent_submissions'),
      );
      expect(
        RepositoryVendorDashboardCache(
          client,
        ).read()!.metrics.recentSubmissions.single.name,
        'Recent event',
      );

      response = {
        'status': {
          'plan': {'plan_code': 'free'},
          'status': 'active',
          'event_used': 10000,
          'attraction_used': 0,
          'image_bytes_used': 0,
        },
        'metrics': {
          'published': 10000,
          'pending': 0,
          'active_events': 10000,
          'active_attractions': 0,
          'totals': {'page_views': 123456},
          'recent_submissions': [],
        },
        'plans': [],
      };
      await ServiceVendorAccount().fetchDashboard(
        'one@example.com',
        force: true,
      );
      expect(requests, hasLength(3));
      expect(jsonDecode(requests.last.body)['p_force_refresh'], true);
      expect(jsonDecode(requests.last.body)['p_include_plans'], true);

      await ServiceVendorAccount().fetchPricingPlans();
      expect(requests, hasLength(3));
    },
  );
  for (final history in [false, true]) {
    test(
      'cloud chart history=$history reads buckets, not raw detail',
      () async {
        response = {
          'months': [...List.filled(11, 0), 5.25],
          'opening': 100,
          'today': -3.25,
          'future': 20,
          'has_history': true,
        };
        final now = DateTime(2026, 10, 1);
        final rows = await ServiceRecordStatistics().read(
          owner: 'one@example.com',
          storage: DataStorageLocation.cloud,
          accountId: '00000000-0000-0000-0000-000000000001',
          kind: RecordStatisticsKind.accounting,
          now: now,
          currency: 'TWD',
          history: history,
        );
        expect(requests, hasLength(1));
        expect(
          requests.single.url.pathSegments.last,
          'get_my_record_statistics',
        );
        expect(rows.length, lessThanOrEqualTo(15));
        final params = jsonDecode(requests.single.body) as Map;
        expect(params['p_boundaries'], hasLength(13));
        expect(params['p_currency'], 'TWD');
        final result = ModelRecordStatistics.fromRows(rows, now: now);
        expect(result.total, 125.25);
        expect(result.today, -3.25);
        expect(result.month, 5.25);
      },
    );
  }
  test(
    'performance first page includes totals; next page requests details only',
    () async {
      response = {
        'items': [
          {'id': 'one', 'page_views': 2},
        ],
        'totals': {'page_views': 100},
        'next_offset': 20,
      };
      final service = ServiceContentPerformance();
      final period = ContentPerformancePeriod(now: DateTime(2026, 10, 30));
      final first = await service.read(
        owner: 'one@example.com',
        attractions: false,
        period: period,
        keyword: '新北',
      );
      expect(jsonDecode(requests[0].body)['p_include_totals'], true);
      response = {
        'items': [
          {'id': 'two', 'page_views': 3},
        ],
        'totals': null,
        'next_offset': null,
      };
      final next = await service.readNextPage(
        owner: 'one@example.com',
        attractions: false,
        period: period,
        keyword: '新北',
        offset: 20,
      );
      expect(requests, hasLength(2));
      expect(jsonDecode(requests[1].body)['p_include_totals'], false);
      final combined = first.appendPage(next!);
      expect(combined.items, hasLength(2));
      expect(combined.totalFor(ContentPerformanceMetric.pageViews), 100);
    },
  );
}
