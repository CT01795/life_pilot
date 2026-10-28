import 'dart:async';
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

  test('successful RPC never invokes Render fallback', () async {
    response = {'updated': true, 'running': false};
    final value = await gateway.rpcOrBackend(
      'life_pilot_public_event_refresh',
      params: {'p_action': 'status'},
      backend: () => throw StateError('Render must not run'),
    );
    expect(value, response);
    expect(
      requests.single.url.path,
      '/rest/v1/rpc/life_pilot_public_event_refresh',
    );
    expect(jsonDecode(requests.single.body), {'p_action': 'status'});
  });

  test('only undeployed RPC uses legacy backend once', () async {
    status = 404;
    response = {'code': 'PGRST202', 'message': 'Function not found'};
    var calls = 0;
    final value = await gateway.rpcOrBackend(
      'missing',
      backend: () async {
        calls++;
        return {'legacy': true};
      },
    );
    expect(value, {'legacy': true});
    expect(calls, 1);
  });

  for (final code in ['42501', 'PGRST301', 'P0001', '42P01', '42883']) {
    test('$code cannot bypass the database error through Render', () async {
      status = 403;
      response = {'code': code, 'message': 'Rejected'};
      var calls = 0;
      await expectLater(
        gateway.rpcOrBackend(
          'rejected',
          backend: () async {
            calls++;
          },
        ),
        throwsA(isA<PostgrestException>()),
      );
      expect(calls, 0);
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

  test('weather miss or undeployed cache calls backend once', () async {
    for (final deployed in [true, false]) {
      status = deployed ? 200 : 404;
      response = deployed ? null : {'code': 'PGRST202', 'message': 'Not found'};
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
    }
  });

  test(
    'fresh holiday cache including empty years never wakes Render',
    () async {
      response = {'cached': true, 'fresh': true, 'items': []};
      final value = await cache.holidays(
        year: 2026,
        language: 'ja',
        backend: () => throw StateError('unnecessary provider request'),
      );
      expect(value['items'], isEmpty);
      expect(jsonDecode(requests.single.body), {
        'p_year': 2026,
        'p_language': 'ja',
      });
    },
  );

  test(
    'stale holidays display immediately and refresh without blocking',
    () async {
      response = {
        'cached': true,
        'fresh': false,
        'items': [
          {'date': '2026-01-01', 'summary': 'old'},
        ],
      };
      final refresh = Completer<dynamic>();
      dynamic updated;
      var calls = 0;
      final value = await cache.holidays(
        year: 2026,
        language: 'zh',
        backend: () {
          calls++;
          return refresh.future;
        },
        onRefreshed: (data) => updated = data,
      );
      expect(value['items'].single['summary'], 'old');
      expect(calls, 1);
      expect(updated, isNull);
      refresh.complete({
        'items': [
          {'date': '2026-01-01', 'summary': 'new'},
        ],
      });
      await Future<void>.delayed(Duration.zero);
      expect(updated['items'].single['summary'], 'new');
    },
  );

  test(
    'stale holiday backend failure keeps cached dates and is handled',
    () async {
      response = {
        'cached': true,
        'fresh': false,
        'items': [
          {'date': '2026-01-01', 'summary': 'cached'},
        ],
      };
      final refresh = Completer<dynamic>();
      final value = await cache.holidays(
        year: 2026,
        language: 'en',
        backend: () => refresh.future,
      );
      refresh.completeError(StateError('Render is asleep'));
      await Future<void>.delayed(Duration.zero);
      expect(value['items'].single['summary'], 'cached');
    },
  );

  test('missing holiday year awaits initial trusted provider fill', () async {
    response = {'cached': false, 'fresh': false, 'items': []};
    final refresh = Completer<dynamic>();
    var finished = false;
    final pending = cache
        .holidays(year: 2026, language: 'ko', backend: () => refresh.future)
        .then((value) {
          finished = true;
          return value;
        });
    await Future<void>.delayed(Duration.zero);
    expect(finished, isFalse);
    refresh.complete({'items': []});
    expect((await pending)['items'], isEmpty);
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
