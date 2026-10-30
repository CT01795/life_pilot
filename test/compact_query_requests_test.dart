import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:life_pilot/utils/supabase.dart';
import 'package:life_pilot/vendor/service_vendor_account.dart';
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
  setUp(() async {
    requests = [];
    client = SupabaseClient(
      'https://example.supabase.co',
      'test-key',
      httpClient: MockClient((request) async {
        requests.add(request);
        return http.Response(
          jsonEncode(response),
          200,
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
  test(
    'vendor dashboard retrieves totals and five previews in one request',
    () async {
      response = {
        'published': 10000,
        'pending': 0,
        'active_events': 10000,
        'active_attractions': 0,
        'totals': {'page_views': 123456},
        'recent_submissions': [],
      };
      final result = await ServiceVendorAccount().fetchMetrics(
        'one@example.com',
      );
      expect(requests, hasLength(1));
      expect(
        requests.single.url.path,
        endsWith('/get_my_vendor_dashboard_metrics'),
      );
      expect(
        result.performance.totalFor(ContentPerformanceMetric.pageViews),
        123456,
      );
    },
  );
  test(
    'historical chart reads thirteen boundaries, not every historical record',
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
        history: true,
      );
      expect(requests, hasLength(1));
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
        statisticsOnly: true,
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
