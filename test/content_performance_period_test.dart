import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:life_pilot/event/controller_content_performance.dart';
import 'package:life_pilot/event/model_content_performance.dart';
import 'package:life_pilot/event/model_content_performance_period.dart';
import 'package:life_pilot/event/service_content_performance.dart';
import 'package:life_pilot/utils/supabase.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'record_statistics_test.dart' show StatisticsTestAuth;
import 'content_performance_and_event_dates_test.dart'
    show PerformanceTestService;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final now = DateTime(2026, 10, 19, 16);
  Map<String, dynamic> dates({DateTime? start, DateTime? end}) => {
    'start_date': start?.toUtc().toIso8601String(),
    'end_date': end?.toUtc().toIso8601String(),
  };
  test(
    'active period includes today and future expirations, but excludes yesterday',
    () {
      final period = ContentPerformancePeriod(now: now);
      expect(period.matches(dates(end: DateTime(2026, 10, 18, 23, 59))), false);
      expect(period.matches(dates(end: DateTime(2026, 10, 19))), true);
      expect(period.matches(dates(end: DateTime(2027))), true);
    },
  );
  test('missing end uses start date; both missing remain active', () {
    final period = ContentPerformancePeriod(now: now);
    expect(period.matches(dates(start: DateTime(2026, 7))), false);
    expect(period.matches(dates(start: DateTime(2026, 10, 19))), true);
    expect(period.matches({}), true);
  });
  test(
    'July selection includes all and only July expirations regardless of start date',
    () {
      final period = ContentPerformancePeriod(
        month: DateTime(2026, 7, 8),
        now: now,
      );
      expect(period.month, DateTime(2026, 7));
      expect(
        period.matches(dates(start: DateTime(2026, 1), end: DateTime(2026, 7))),
        true,
      );
      expect(period.matches(dates(end: DateTime(2026, 7, 31, 23, 59))), true);
      expect(period.matches(dates(end: DateTime(2026, 6, 30, 23, 59))), false);
      expect(
        period.matches(dates(start: DateTime(2026, 7), end: DateTime(2026, 8))),
        false,
      );
      expect(period.matches(dates(start: DateTime(2026, 7, 15))), true);
      expect(period.matches({}), false);
    },
  );
  test('December month range rolls over to January in the correct year', () {
    final period = ContentPerformancePeriod(
      month: DateTime(2025, 12),
      now: now,
    );
    expect(period.matches(dates(end: DateTime(2025, 12, 31, 23, 59))), true);
    expect(period.matches(dates(end: DateTime(2026))), false);
    expect(
      period.databaseFilter,
      contains(DateTime(2026).toUtc().toIso8601String()),
    );
  });
  test('changing selected month invalidates older pending responses', () async {
    final auth = StatisticsTestAuth();
    final service = PerformanceTestService();
    final controller = ControllerContentPerformance(
      auth: auth,
      attractions: false,
      service: service,
    );
    final first = controller.load();
    expect(service.periods.first!.month, null);
    final second = controller.selectMonth(DateTime(2026, 7), keyword: 'July');
    expect(controller.data, null);
    expect(service.periods.last!.month, DateTime(2026, 7));
    expect(service.keywords.last, 'July');
    service.pending[1].complete(
      ModelContentPerformance([
        {'name': 'July'},
      ]),
    );
    await second;
    service.pending[0].complete(
      ModelContentPerformance([
        {'name': 'active'},
      ]),
    );
    await first;
    expect(controller.data!.rows.single['name'], 'July');
    final active = controller.selectMonth(null);
    expect(service.periods.last!.month, null);
    service.pending[2].complete(ModelContentPerformance([]));
    await active;
    controller.dispose();
    auth.dispose();
  });

  test(
    'selecting the current month includes only that month expirations, including past days',
    () {
      final period = ContentPerformancePeriod(
        month: DateTime(2026, 10),
        now: now,
      );
      expect(period.month, DateTime(2026, 10));
      expect(period.matches(dates(end: DateTime(2027, 7))), false);
      expect(period.matches(dates(end: DateTime(2026, 10, 18))), true);
      expect(period.matches(dates(end: DateTime(2026, 10, 31, 23, 59))), true);
      expect(period.matches(dates(end: DateTime(2026, 11))), false);
      expect(period.databaseFilter, contains('.lt.'));
    },
  );
  test(
    'activity expiration ascending then city ascending, start descending, and no-expiry last',
    () {
      final rows = <Map<String, dynamic>>[
        {'id': 'no-date'},
        {
          'id': 'old',
          ...dates(start: DateTime(2026, 1), end: DateTime(2026, 7, 1)),
        },
        {
          'id': 'B',
          'city': 'B',
          ...dates(start: DateTime(2026, 6), end: DateTime(2026, 7, 31)),
        },
        {
          'id': 'A',
          'city': 'A',
          ...dates(start: DateTime(2026, 6), end: DateTime(2026, 7, 31)),
        },
        {
          'id': 'earlier-start',
          ...dates(start: DateTime(2026, 5), end: DateTime(2026, 7, 31)),
        },
        {'id': 'no-end-future', ...dates(start: DateTime(2027))},
      ]..sort(compareContentPerformance);
      expect(rows.map((r) => r['id']), [
        'old',
        'earlier-start',
        'A',
        'B',
        'no-end-future',
        'no-date',
      ]);
    },
  );
  test(
    'keyword search quotes punctuation and escapes SQL pattern wildcards',
    () {
      final filter = contentPerformanceSearchFilter('A,B("x")%_');
      expect(filter, startsWith('name.ilike."'));
      expect(filter, contains('city.ilike."'));
      expect(filter, contains(r'\"x\"'));
      expect(filter, contains(r'\\%'));
      expect(filter, contains(r'\\_'));
    },
  );

  group('database scope and pagination', () {
    late SupabaseClient client;
    late List<http.Request> requests;
    var active = true, expireOnResponse = false, missing = false;
    setUp(() async {
      requests = [];
      active = true;
      expireOnResponse = false;
      missing = false;
      client = SupabaseClient(
        'https://example.supabase.co',
        'test-key',
        httpClient: MockClient((request) async {
          requests.add(request);
          if (expireOnResponse) active = false;
          return http.Response(
            jsonEncode(
              missing
                  ? {'code': 'PGRST202', 'message': 'missing'}
                  : {
                      'items': [
                        {'id': 'one', 'page_views': 2},
                      ],
                      'totals': {'page_views': 20},
                      'next_offset': 20,
                    },
            ),
            missing ? 404 : 200,
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
            'aud': 'authenticated',
            'created_at': '2026-01-01T00:00:00Z',
          },
        }),
      );
    });
    tearDown(() => client.dispose());
    test('inactive query sends no database request', () async {
      active = false;
      final data = await ServiceContentPerformance().read(
        owner: 'one@example.com',
        attractions: false,
        period: ContentPerformancePeriod(now: now),
        shouldContinue: () => active,
      );
      expect(data.items, isEmpty);
      expect(requests, isEmpty);
    });
    for (final attractions in [false, true]) {
      for (final month in [
        null,
        DateTime(2026, 7),
        DateTime(2026, 10),
        DateTime(2025, 12),
      ]) {
        test(
          'RPC scopes month and keyword without downloading all content ($attractions, $month)',
          () async {
            final period = ContentPerformancePeriod(month: month, now: now);
            final data = await ServiceContentPerformance().read(
              owner: 'one@example.com',
              attractions: attractions,
              period: period,
              keyword: '  新北,(活動)%_  ',
            );
            expect(data.items.single.id, 'one');
            expect(data.totals['page_views'], 20);
            expect(data.hasMore, true);
            expect(requests, hasLength(1));
            expect(
              requests.single.url.pathSegments.last,
              'get_my_content_performance_page',
            );
            final params = jsonDecode(requests.single.body);
            expect(params['p_attractions'], attractions);
            expect(params['p_unexpired'], month == null);
            expect(params['p_keyword'], '新北,(活動)%_');
            expect(
              params['p_from'],
              (month ?? period.today).toUtc().toIso8601String(),
            );
            expect(
              params['p_to'],
              month == null
                  ? null
                  : DateTime(
                      month.year,
                      month.month + 1,
                    ).toUtc().toIso8601String(),
            );
            expect(params['p_limit'], 20);
            expect(params['p_offset'], 0);
            expect(params['p_include_totals'], true);
            expect(params.containsKey('p_owner'), false);
          },
        );
      }
      test('expired response publishes no content ($attractions)', () async {
        expireOnResponse = true;
        final data = await ServiceContentPerformance().read(
          owner: 'one@example.com',
          attractions: attractions,
          period: ContentPerformancePeriod(now: now),
          shouldContinue: () => active,
        );
        expect(data.items, isEmpty);
        expect(requests, hasLength(1));
      });
    }
    test('different logged-in author is rejected before querying', () async {
      await expectLater(
        ServiceContentPerformance().read(
          owner: 'other@example.com',
          attractions: false,
          period: ContentPerformancePeriod(now: now),
        ),
        throwsStateError,
      );
      expect(requests, isEmpty);
    });
    test('missing RPC reports failure without direct table fallback', () async {
      missing = true;
      await expectLater(
        ServiceContentPerformance().read(
          owner: 'one@example.com',
          attractions: false,
          period: ContentPerformancePeriod(now: now),
        ),
        throwsA(isA<PostgrestException>()),
      );
      expect(requests, hasLength(1));
      expect(
        requests.single.url.pathSegments.last,
        'get_my_content_performance_page',
      );
    });
  });
}
