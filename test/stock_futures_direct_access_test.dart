import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:life_pilot/stock/repository_stock_futures.dart';
import 'package:life_pilot/stock/service_stock.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  late SupabaseClient client;
  late RepositoryStockFutures repository;
  late List<http.Request> requests;
  dynamic response;
  var status = 200;
  setUp(() {
    requests = [];
    response = [];
    status = 200;
    client = SupabaseClient(
      'https://example.supabase.co',
      'test-public-key',
      httpClient: MockClient((request) async {
        requests.add(request);
        return http.Response(
          jsonEncode(response),
          status,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      }),
    );
    repository = RepositoryStockFutures(client: client);
  });
  tearDown(() => client.dispose());

  test(
    'futures read calls Supabase REST directly with the selected day',
    () async {
      await repository.readDate(DateTime(2026, 10, 28, 23, 59));
      final request = requests.single;
      expect(request.method, 'GET');
      expect(request.url.host, 'example.supabase.co');
      expect(request.url.path, '/rest/v1/futures_institutional');
      expect(request.url.queryParameters['date'], 'eq.2026-10-28');
      expect(
        request.url.queryParameters['select'],
        'product_name,identity_type,oi_long_qty,oi_short_qty,oi_net_qty',
      );
      expect(request.headers['apikey'], 'test-public-key');
    },
  );

  test('direct reads preserve legacy product and identity ordering', () async {
    response = [
      {'product_name': '電子期貨', 'identity_type': 'b'},
      {'product_name': '臺股期貨', 'identity_type': 'b'},
      {'product_name': '小型臺指期貨', 'identity_type': 'a'},
      {'product_name': '臺股期貨', 'identity_type': 'a'},
    ];
    final rows = await repository.readDate(DateTime(2026, 10, 28));
    expect(
      rows.map((row) => '${row['product_name']}:${row['identity_type']}'),
      ['臺股期貨:a', '臺股期貨:b', '小型臺指期貨:a', '電子期貨:b'],
    );
  });

  test('empty cloud result stays empty', () async {
    expect(await repository.readDate(DateTime(2026, 10, 28)), isEmpty);
    expect(requests, hasLength(1));
  });

  test('permission errors propagate without a Render fallback', () async {
    status = 403;
    response = {'code': '42501', 'message': 'permission denied'};
    await expectLater(
      repository.readDate(DateTime(2026, 10, 28)),
      throwsA(isA<PostgrestException>()),
    );
    expect(requests, hasLength(1));
  });

  test(
    'service computes previous-day changes entirely through Supabase',
    () async {
      // Same response on both days makes the position difference zero.
      response = [
        {
          'product_name': '臺股期貨',
          'identity_type': 'foreign investor',
          'oi_long_qty': 800,
          'oi_short_qty': 300,
          'oi_net_qty': 500,
          'date': '2026-10-27T00:00:00Z',
        },
      ];
      final service = ServiceStock(futuresRepository: repository);
      final rows = await service.selectFutures(DateTime(2026, 10, 28));
      expect(rows.single.oiNetQty, 500);
      expect(rows.single.oiNetQtyDiff, 0);
      expect(requests, hasLength(3));
      expect(requests.first.url.queryParameters['date'], 'eq.2026-10-28');
      expect(requests[1].url.queryParameters['select'], 'date');
      expect(
        requests[1].url.queryParametersAll['date'],
        containsAll(['gte.2026-10-14', 'lt.2026-10-28']),
      );
      expect(requests[1].url.queryParameters['limit'], '1');
      expect(requests.last.url.queryParameters['date'], 'eq.2026-10-27');
      expect(
        requests.every((request) => request.url.host == 'example.supabase.co'),
        isTrue,
      );
    },
  );
}
