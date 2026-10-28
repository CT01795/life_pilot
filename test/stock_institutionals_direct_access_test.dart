import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:life_pilot/stock/repository_stock_institutionals.dart';
import 'package:life_pilot/stock/service_stock.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  late SupabaseClient client;
  late ServiceStock service;
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
    service = ServiceStock(
      institutionalsRepository: RepositoryStockInstitutionals(client: client),
    );
  });
  tearDown(() => client.dispose());

  for (final date in [
    DateTime(2026, 10, 28, 23, 59),
    DateTime.utc(2028, 2, 29, 1),
  ]) {
    test('reads four fields for the selected calendar day: $date', () async {
      response = [
        {
          'stock_no': '2',
          'stock_name': 'Second',
          'foreign_diff': -500,
          'total_diff': 200,
        },
        {
          'stock_no': '1',
          'stock_name': 'First',
          'foreign_diff': 1000,
          'total_diff': 800,
        },
      ];
      final rows = await service.selectStockInstitutional(date);
      expect(rows.map((row) => row.stockNo), ['2', '1']);
      expect(rows.first.foreignDiff, -500);
      expect(rows.first.totalDiff, 200);
      final request = requests.single;
      expect(request.method, 'GET');
      expect(request.url.host, 'example.supabase.co');
      expect(request.url.path, '/rest/v1/stock_institutional');
      expect(
        request.url.queryParameters['select'],
        'stock_no,stock_name,foreign_diff,total_diff',
      );
      expect(
        request.url.queryParameters['date'],
        'eq.${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
      );
      expect(request.url.queryParameters['order'], isNull);
    });
  }

  test('empty day does not fall back to another day', () async {
    expect(
      await service.selectStockInstitutional(DateTime(2026, 10, 1)),
      isEmpty,
    );
    expect(requests, hasLength(1));
  });

  test('permission error propagates and retry reads fresh data', () async {
    status = 403;
    response = {'message': 'permission denied', 'code': '42501'};
    final date = DateTime(2026, 10, 28);
    await expectLater(
      service.selectStockInstitutional(date),
      throwsA(isA<PostgrestException>()),
    );
    status = 200;
    response = [
      {
        'stock_no': '2330',
        'stock_name': 'Fresh',
        'foreign_diff': '12',
        'total_diff': '-3',
      },
    ];
    final rows = await service.selectStockInstitutional(date);
    expect(rows.single.stockName, 'Fresh');
    expect(rows.single.foreignDiff, 12);
    expect(rows.single.totalDiff, -3);
    expect(requests, hasLength(2));
  });

  test(
    'repeated successful reads do not retain a completed result',
    () async {
      final date = DateTime(2026, 10, 28);
      response = [
        {
          'stock_no': '1',
          'stock_name': 'Before',
          'foreign_diff': 1,
          'total_diff': 2,
        },
      ];
      final first = await service.selectStockInstitutional(date);
      response = [
        {
          'stock_no': '2',
          'stock_name': 'After',
          'foreign_diff': 3,
          'total_diff': 4,
        },
      ];
      final second = await service.selectStockInstitutional(date);
      expect(first.single.stockName, 'Before');
      expect(second.single.stockName, 'After');
      expect(requests, hasLength(2));
    },
  );
}
