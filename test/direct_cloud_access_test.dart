import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:life_pilot/event/service_event_public.dart';
import 'package:life_pilot/utils/repository_cloud_gateway.dart';
import 'package:life_pilot/utils/repository_external_cache.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  late SupabaseClient client;
  late RepositoryCloudGateway gateway;
  late RepositoryExternalCache cache;
  late List<http.Request> requests;
  dynamic response;
  var status = 200;
  setUp(() {
    requests = [];
    response = null;
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
    gateway = RepositoryCloudGateway(client: client);
    cache = RepositoryExternalCache(gateway: gateway);
  });
  tearDown(() => client.dispose());

  test('successful RPC uses Supabase directly', () async {
    response = {'updated': true, 'running': false};
    final value = await gateway.rpc(
      'life_pilot_public_event_refresh',
      params: {'p_action': 'status'},
    );
    expect(value, response);
    expect(
      requests.single.url.path,
      '/rest/v1/rpc/life_pilot_public_event_refresh',
    );
    expect(jsonDecode(requests.single.body), {'p_action': 'status'});
  });

  for (final code in [
    'PGRST202',
    '42501',
    'PGRST301',
    'P0001',
    '42P01',
    '42883',
  ]) {
    test('$code propagates without a provider request', () async {
      status = code == 'PGRST202' ? 404 : 403;
      response = {'code': code, 'message': 'Rejected'};
      final rejects = throwsA(
        isA<PostgrestException>().having((e) => e.code, 'code', code),
      );
      Future<dynamic> unexpected() async =>
          throw StateError('Provider must not run');
      await expectLater(
        cache.weather(lat: 25, lng: 121, backend: unexpected),
        rejects,
      );
      await expectLater(
        cache.weatherBatch(locations: const [(lat: 25.0, lng: 121.0)]),
        rejects,
      );
      await expectLater(
        cache.holidayYears(years: const [2026], language: 'zh'),
        rejects,
      );
    });
  }

  test('weather hit reads only shared Supabase results', () async {
    response = {'items': [], 'expires_at': '2027-01-01T00:00:00Z'};
    final result = await cache.weather(
      lat: 25.1,
      lng: 121.5,
      backend: () => throw StateError('unnecessary provider request'),
    );
    expect(result, response);
    expect(requests.single.url.path, '/rest/v1/rpc/life_pilot_cached_weather');
    expect(jsonDecode(requests.single.body), {'p_lat': 25.1, 'p_lng': 121.5});
  });

  test('weather cache miss calls provider once', () async {
    response = null;
    var calls = 0;
    final result = await cache.weather(
      lat: 25,
      lng: 121,
      backend: () async {
        calls++;
        return {'items': [], 'expires_at': '2027-01-01T00:00:00Z'};
      },
    );
    expect(result['items'], isEmpty);
    expect(calls, 1);
  });

  test('holiday years use one ordered batch cache query', () async {
    response = [
      {'year': 2026, 'cached': true, 'fresh': true, 'items': []},
      {
        'year': 2027,
        'cached': true,
        'fresh': false,
        'items': [
          {'date': '2027-01-01', 'summary': 'New Year'},
        ],
      },
    ];
    final value = await cache.holidayYears(
      years: const [2026, 2027],
      language: 'ja',
    );
    expect(value.map((row) => row['year']), [2026, 2027]);
    expect(value.last['fresh'], isFalse);
    expect(
      requests.single.url.path,
      endsWith('life_pilot_cached_holidays_batch'),
    );
    expect(jsonDecode(requests.single.body), {
      'p_years': [2026, 2027],
      'p_language': 'ja',
    });
  });

  test('public event service status uses Supabase gateway', () async {
    response = {'updated': true, 'running': false};
    final service = ServiceEventPublic(cloudGateway: gateway);
    addTearDown(service.close);
    final value = await service.getRefreshStatus();
    expect(value.updated, isTrue);
    expect(value.running, isFalse);
    expect(
      requests.single.url.path,
      '/rest/v1/rpc/life_pilot_public_event_refresh',
    );
  });
}
