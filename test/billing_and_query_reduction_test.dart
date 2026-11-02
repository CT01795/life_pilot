import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:life_pilot/subscription/model_billing_cycle.dart';
import 'package:life_pilot/subscription/repository_pricing_catalog.dart';
import 'package:life_pilot/utils/service/export/repository_personal_export_rows.dart';
import 'package:life_pilot/feedback/service_feedback.dart';
import 'package:life_pilot/utils/supabase.dart';

Future<void> signIn(
  SupabaseClient client, {
  String id = 'owner',
  String email = 'one@example.com',
}) => client.auth.setInitialSession(
  jsonEncode({
    'access_token': 'token-$id',
    'token_type': 'bearer',
    'user': {
      'id': id,
      'email': email,
      'app_metadata': {},
      'user_metadata': {},
      'aud': 'authenticated',
      'created_at': '2026-01-01T00:00:00Z',
    },
  }),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SupabaseClient client;
  late List<http.Request> requests;
  Object? response;
  Completer<void>? gate;
  var time = DateTime(2026, 11, 2);
  setUp(() async {
    requests = [];
    gate = null;
    response = {
      'versions': [
        {'id': 'v', 'billing_cycle': 'month', 'quarterly_price_twd': 99},
      ],
    };
    time = DateTime(2026, 11, 2);
    client = SupabaseClient(
      'https://example.supabase.co',
      'key',
      httpClient: MockClient((request) async {
        requests.add(request);
        final body =
            (request.url.path.endsWith('export_my_cloud_data_for_local') ||
                    request.url.path.endsWith(
                      'export_my_personal_excel_rows',
                    )) &&
                request.url.queryParameters['offset'] == '1000'
            ? [
                {
                  'table_name': 'memory_trace',
                  'id': 'last',
                  'start_date': '2029-01-01',
                },
              ]
            : response;
        if (gate != null) await gate!.future;
        return http.Response(
          jsonEncode(body),
          200,
          request: request,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    supabase = client;
    await signIn(client);
  });
  tearDown(() => client.dispose());

  test(
    'month/quarter use calendar arithmetic and preserve legacy defaults',
    () {
      expect(BillingCycle.from(null), BillingCycle.quarter);
      expect(
        BillingCycle.month.endFrom(DateTime(2027, 1, 31, 12)),
        DateTime(2027, 2, 28, 12),
      );
      expect(
        BillingCycle.month.endFrom(DateTime(2028, 1, 31, 12)),
        DateTime(2028, 2, 29, 12),
      );
      expect(
        BillingCycle.quarter.endFrom(DateTime.utc(2026, 11, 30, 12)),
        DateTime.utc(2027, 2, 28, 12),
      );
      expect(() => BillingCycle.from('year'), throwsFormatException);
    },
  );
  test(
    'display cache expires; authority reads never reuse completed values',
    () async {
      final repo = RepositoryPricingCatalog(client: client, now: () => time);
      await repo.read(vendor: false, displayOnly: true);
      await repo.read(vendor: false, displayOnly: true);
      expect(requests, hasLength(1));
      await repo.read(vendor: false);
      expect(requests, hasLength(2));
      time = time.add(const Duration(seconds: 31));
      await repo.read(vendor: false, displayOnly: true);
      expect(requests, hasLength(3));
    },
  );
  test('concurrent catalog reads share one query', () async {
    final repo = RepositoryPricingCatalog(client: client);
    gate = Completer<void>();
    final first = repo.read(vendor: true);
    final second = repo.read(vendor: true);
    await Future<void>.delayed(Duration.zero);
    gate!.complete();
    await Future.wait([first, second]);
    expect(requests, hasLength(1));
  });
  test('saving invalidates completed display data', () async {
    final repo = RepositoryPricingCatalog(client: client);
    await repo.read(vendor: false, displayOnly: true);
    await repo.save(vendor: false, payload: {'billing_cycle': 'month'});
    await repo.read(vendor: false, displayOnly: true);
    expect(requests, hasLength(3));
  });
  test(
    'account change cannot reuse catalog or publish old pending data',
    () async {
      final repo = RepositoryPricingCatalog(client: client);
      gate = Completer<void>();
      final old = repo.read(vendor: false);
      final expectation = expectLater(old, throwsStateError);
      await signIn(client, id: 'other', email: 'two@example.com');
      gate!.complete();
      await expectation;
      gate = null;
      await repo.read(vendor: false, displayOnly: true);
      expect(requests, hasLength(2));
    },
  );
  test(
    'Excel query excludes images/games, preserves numeric JSON and no date limit',
    () async {
      response = [
        {
          'table_name': 'accounting_detail',
          'id': 'd',
          'value': 1234.5678,
          'date': '2028-01-01',
          'currency': 'TWD',
          'group': 'food',
        },
      ];
      final rows = await RepositoryPersonalExportRows(
        client: client,
      ).read('one@example.com');
      expect(rows.single['value'], 1234.5678);
      expect(rows.single['date'], '2028-01-01');
      final params = requests.single.url.queryParameters;
      expect(params['select'], contains('value:record->value'));
      expect(params['select'], isNot(contains('master_graph_url')));
      expect(params['select'], isNot(contains('sub_events')));
      expect(params['table_name'], isNot(contains('game_')));
      expect(params['table_name'], contains('point_record_detail'));
      expect(params['order'], contains('record->>id'));
      expect(params.keys, isNot(contains('date')));
    },
  );
  test('Excel pagination includes all dates and final page', () async {
    response = List.generate(
      1000,
      (i) => {'table_name': 'memory_trace', 'id': '$i'},
    );
    final rows = await RepositoryPersonalExportRows(
      client: client,
    ).read('one@example.com');
    expect(rows, hasLength(1001));
    expect(rows.last['start_date'], '2029-01-01');
    expect(requests, hasLength(2));
  });
  test('Excel rejects mismatched account before any query', () async {
    await expectLater(
      RepositoryPersonalExportRows(client: client).read('two@example.com'),
      throwsStateError,
    );
    expect(requests, isEmpty);
  });
  test(
    'feedback metadata excludes screenshots; explicit detail fetch reads them',
    () async {
      response = [];
      await ServiceFeedback().loadFeedback(
        dateFrom: DateTime(2026),
        dateTo: DateTime(2027),
      );
      expect(
        requests.single.url.queryParameters['select'],
        isNot(contains('screenshot')),
      );
      expect(
        requests.single.url.queryParameters['select']!.split(','),
        isNot(contains('cc')),
      );
      response = {
        'screenshot': ['encoded-image'],
      };
      expect(await ServiceFeedback().loadScreenshots(3), ['encoded-image']);
      expect(requests.last.url.queryParameters['select'], 'screenshot');
      expect(requests.last.url.queryParameters['id'], 'eq.3');
    },
  );
}
