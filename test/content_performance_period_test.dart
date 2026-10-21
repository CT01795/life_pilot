import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:life_pilot/event/controller_content_performance.dart';
import 'package:life_pilot/event/model_content_performance.dart';
import 'package:life_pilot/event/model_content_performance_period.dart';
import 'package:life_pilot/event/service_content_performance.dart';
import 'package:life_pilot/utils/api.dart' as api;
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
    late List<Uri> requests;
    late List<Map<String, dynamic>> rows;
    bool duplicate = false;
    bool active = true;
    bool expireOnResponse = false;
    setUp(() async {
      requests = [];
      duplicate = false;
      active = true;
      expireOnResponse = false;
      rows = [
        for (var i = 0; i < 3; i++) {'id': '$i', 'name': '$i', 'page_views': i},
      ];
      client = SupabaseClient(
        'https://example.supabase.co',
        'test-key',
        httpClient: MockClient((request) async {
          requests.add(request.url);
          if (expireOnResponse) active = false;
          final offset = int.parse(
            request.url.queryParameters['offset'] ?? '0',
          );
          // Emulate a server cap smaller than the requested page size.
          return http.Response(
            jsonEncode(rows.skip(duplicate ? 0 : offset).take(2).toList()),
            200,
            headers: {'content-type': 'application/json'},
            request: request,
          );
        }),
      );
      api.supabase = client;
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
    test('inactive performance query sends no database request', () async {
      active = false;
      final result = await ServiceContentPerformance().read(
        owner: 'one@example.com',
        attractions: false,
        shouldContinue: () => active,
      );
      expect(requests, isEmpty);
      expect(result.items, isEmpty);
    });
    for (final attractions in [false, true]) {
      test(
        '$attractions expired HTTP response does not trigger another page',
        () async {
          expireOnResponse = true;
          final result = await ServiceContentPerformance().read(
            owner: 'one@example.com',
            attractions: attractions,
            shouldContinue: () => active,
          );
          expect(requests.length, 1);
          expect(result.items, isEmpty);
          expect(result.totals.values.every((value) => value == 0), true);
        },
      );
    }
    test(
      'statistics-only search keeps author, date, keyword and six nonzero counters as mandatory groups',
      () async {
        final period = ContentPerformancePeriod(now: now);
        final result = await ServiceContentPerformance().read(
          owner: 'one@example.com',
          attractions: true,
          period: period,
          keyword: '新北',
          statisticsOnly: true,
        );
        expect(result.items.map((item) => item.id), ['1', '2']);
        expect(
          requests.length,
          3,
        ); // Raw page offsets remain correct after zero rows are hidden.
        for (final request in requests) {
          final filter = request.queryParameters['or']!;
          expect(filter, startsWith('(and('));
          expect(filter, contains('or(${period.databaseFilter})'));
          expect(filter, contains(contentPerformanceSearchFilter('新北')));
          for (final column in contentPerformanceColumns) {
            expect(filter, contains('$column.neq.0'));
          }
          expect(request.queryParameters['account'], 'eq.one@example.com');
          expect(
            request.queryParameters['order'],
            'end_date.asc.nullslast,city.asc.nullslast,start_date.asc.nullslast,id.asc.nullslast',
          );
        }
      },
    );
    test(
      'keyword and month are ANDed while names and cities are ORed; author scope stays mandatory',
      () async {
        final period = ContentPerformancePeriod(
          month: DateTime(2026, 7),
          now: now,
        );
        const keyword = 'Taipei,festival';
        await ServiceContentPerformance().read(
          owner: 'one@example.com',
          attractions: false,
          period: period,
          keyword: keyword,
        );
        for (final request in requests) {
          expect(request.queryParameters['account'], 'eq.one@example.com');
          expect(
            request.queryParameters['or'],
            '(and(or(${period.databaseFilter}),or(${contentPerformanceSearchFilter(keyword)})))',
          );
          expect(
            request.queryParameters['order'],
            contains(
              'end_date.asc.nullslast,city.asc.nullslast,start_date.desc.nullslast,id.asc.nullslast',
            ),
          );
        }
      },
    );
    for (final attractions in [false, true]) {
      test(
        '$attractions: filters expiration month on the server and retains author isolation on every page',
        () async {
          final period = ContentPerformancePeriod(
            month: DateTime(2026, 7),
            now: now,
          );
          final data = await ServiceContentPerformance().read(
            owner: 'one@example.com',
            attractions: attractions,
            period: period,
          );
          expect(data.rows.length, 3);
          expect(data.totals['page_views'], 3);
          expect(requests.length, 3);
          for (final request in requests) {
            expect(
              request.path,
              endsWith(
                attractions ? 'recommended_attractions' : 'recommended_events',
              ),
            );
            expect(request.queryParameters['account'], 'eq.one@example.com');
            expect(request.queryParameters['or'], '(${period.databaseFilter})');
            expect(request.queryParameters['select'], contains('end_date'));
            expect(
              request.queryParameters['select'],
              isNot(contains('master_graph_url')),
            );
          }
        },
      );
    }
    test(
      'active period applies current date filter before downloading any rows',
      () async {
        final period = ContentPerformancePeriod(now: now);
        await ServiceContentPerformance().read(
          owner: 'one@example.com',
          attractions: false,
          period: period,
        );
        expect(
          requests.first.queryParameters['or'],
          '(${period.databaseFilter})',
        );
      },
    );
    test(
      'vendor metadata overview can still read all content without a period filter',
      () async {
        await ServiceContentPerformance().read(
          owner: 'one@example.com',
          attractions: false,
          includeSubmissionDetails: true,
        );
        expect(requests.first.queryParameters['or'], null);
        expect(
          requests.first.queryParameters['select'],
          contains('city,start_date,end_date'),
        );
      },
    );
    test(
      'requests for a different logged-in author fail before querying',
      () async {
        await expectLater(
          ServiceContentPerformance().read(
            owner: 'other@example.com',
            attractions: false,
          ),
          throwsStateError,
        );
        expect(requests, isEmpty);
      },
    );
    test(
      'repeated pages fail safely rather than doubling totals or looping',
      () async {
        duplicate = true;
        await expectLater(
          ServiceContentPerformance().read(
            owner: 'one@example.com',
            attractions: false,
          ),
          throwsStateError,
        );
        expect(requests.length, 2);
      },
    );
  });
}
