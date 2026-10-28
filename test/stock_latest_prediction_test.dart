import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:life_pilot/stock/repository_stock_predictions.dart';
import 'package:life_pilot/stock/service_stock.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  late SupabaseClient client;
  late RepositoryStockPredictions repository;
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
    repository = RepositoryStockPredictions(client: client);
  });
  tearDown(() => client.dispose());

  test('latest date fallback requests only one date without content', () async {
    response = [
      {'date': '2026-10-28T00:00:00Z'},
    ];
    final date = await ServiceStock(
      predictionsRepository: repository,
    ).getLatestDate();
    expect(date, DateTime.utc(2026, 10, 28));
    final request = requests.single;
    expect(request.url.path, '/rest/v1/stock_predicted');
    expect(request.url.queryParameters['select'], 'date');
    expect(request.url.queryParameters['order'], 'date.desc.nullslast');
    expect(request.url.queryParameters['limit'], '1');
  });

  test('unavailable latest date remains null without a second query', () async {
    for (final value in [
      [],
      [
        {'date': null},
      ],
      [
        {'date': 'invalid'},
      ],
    ]) {
      response = value;
      final before = requests.length;
      expect(await repository.readLatestDate(), isNull);
      expect(requests.length, before + 1);
    }
  });

  test(
    'latest date failure propagates and a retry observes a new date',
    () async {
      final service = ServiceStock(predictionsRepository: repository);
      status = 403;
      response = {'code': '42501', 'message': 'permission denied'};
      await expectLater(
        service.getLatestDate(),
        throwsA(isA<PostgrestException>()),
      );
      status = 200;
      response = [
        {'date': '2026-10-29T00:00:00Z'},
      ];
      expect(await service.getLatestDate(), DateTime.utc(2026, 10, 29));
      expect(requests, hasLength(2));
    },
  );

  for (final day in [
    DateTime(2026, 10, 28, 23, 59),
    DateTime.utc(2028, 2, 29, 12),
  ]) {
    test('historical service queries the chosen UTC calendar day: $day', () async {
      response = [
        {
          'data': [
            {
              'date': '2026-10-28T00:00:00Z',
              'security_code': '2330',
              'security_name': 'history',
              'closing_price': 100,
            },
          ],
        },
      ];
      final rows = await ServiceStock(
        predictionsRepository: repository,
      ).getSimpleStrategyForDate(day);
      expect(rows.single.securityName, 'history');
      final request = requests.single;
      expect(request.url.path, '/rest/v1/stock_predicted');
      expect(request.url.queryParameters['select'], 'data');
      expect(
        request.url.queryParametersAll['date'],
        containsAll([
          'gte.${DateTime.utc(day.year, day.month, day.day).toIso8601String()}',
          'lt.${DateTime.utc(day.year, day.month, day.day + 1).toIso8601String()}',
        ]),
      );
      expect(request.url.queryParameters['limit'], '1');
      expect(request.url.queryParameters['order'], isNull);
    });
  }

  test(
    'a missing historical day stays empty and never falls back to latest',
    () async {
      expect(await repository.readDate(DateTime(2026, 10, 1)), isEmpty);
      expect(requests, hasLength(1));
      expect(requests.single.url.queryParameters['order'], isNull);
    },
  );

  test(
    'historical errors propagate without another query or backend call',
    () async {
      status = 403;
      response = {'code': '42501', 'message': 'permission denied'};
      await expectLater(
        repository.readDate(DateTime(2026, 10, 1)),
        throwsA(isA<PostgrestException>()),
      );
      expect(requests, hasLength(1));
    },
  );

  test(
    'latest snapshot uses one direct query for both date and content',
    () async {
      response = [
        {
          'date': '2026-10-28T00:00:00Z',
          'data': [
            {
              'date': '2026-10-28T00:00:00Z',
              'security_code': '2330',
              'security_name': 'TSMC',
              'closing_price': 100,
            },
            {
              'date': '2026-10-28T00:00:00Z',
              'security_code': '2330',
              'security_name': 'duplicate',
              'closing_price': 101,
            },
          ],
        },
      ];
      final service = ServiceStock(predictionsRepository: repository);
      final rows = await service.getSimpleStrategySupabase('From Supabase 1');
      expect(rows, hasLength(1));
      expect(rows.single.securityName, 'API: TSMC');
      expect(rows.single.level, 'From Supabase 1');
      expect(rows.single.date, DateTime.utc(2026, 10, 28));
      final request = requests.single;
      expect(request.method, 'GET');
      expect(request.url.host, 'example.supabase.co');
      expect(request.url.path, '/rest/v1/stock_predicted');
      expect(request.url.queryParameters['select'], 'date,data');
      expect(request.url.queryParameters['order'], 'date.desc.nullslast');
      expect(request.url.queryParameters['limit'], '1');
    },
  );

  for (final value in <dynamic>[
    [],
    [
      {'date': '2026-10-28', 'data': null},
    ],
    [
      {'data': 'invalid'},
    ],
  ]) {
    test('empty or unavailable content returns no rows: $value', () async {
      response = value;
      expect(await repository.readLatest(), isEmpty);
      expect(requests, hasLength(1));
    });
  }

  test(
    'query failure propagates so the controller can choose its fallback',
    () async {
      status = 403;
      response = {'code': '42501', 'message': 'permission denied'};
      await expectLater(
        repository.readLatest(),
        throwsA(isA<PostgrestException>()),
      );
      expect(requests, hasLength(1));
    },
  );
}
