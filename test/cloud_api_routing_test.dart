import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:life_pilot/auth/auth_session_guard.dart';
import 'package:life_pilot/utils/service/service_api.dart';
import 'package:life_pilot/utils/service/service_cloud_api.dart';

Future<void> login(SupabaseClient client, String id) =>
    client.auth.setInitialSession(
      jsonEncode({
        'access_token': 'token-$id',
        'token_type': 'bearer',
        'user': {
          'id': id,
          'email': '$id@example.com',
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
  Completer<void>? gate;
  var status = 200;
  setUp(() async {
    requests = [];
    gate = null;
    status = 200;
    client = SupabaseClient(
      'https://example.supabase.co',
      'public-key',
      httpClient: MockClient((request) async {
        requests.add(request);
        if (gate != null) await gate!.future;
        return http.Response(
          jsonEncode(status == 200 ? {'items': []} : {'code': 'invalid_jwt'}),
          status,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    await login(client, 'one');
  });
  tearDown(() async => client.dispose());
  test(
    'secret-bearing route calls Supabase Functions with current caller JWT',
    () async {
      await ServiceCloudApi(
        client: client,
      ).post('/external/weather', {'lat': 25, 'lng': 121});
      expect(requests.single.url.host, 'example.supabase.co');
      expect(requests.single.url.path, '/functions/v1/life-pilot-services');
      expect(
        requests.single.headers['Authorization'] ??
            requests.single.headers['authorization'],
        'Bearer token-one',
      );
      expect(jsonDecode(requests.single.body), {
        'route': 'external/weather',
        'method': 'POST',
        'body': {'lat': 25, 'lng': 121},
      });
    },
  );
  test('identical external reads reuse a short-lived response', () async {
    final service = ServiceCloudApi(client: client);

    final first = await service.post('/external/weather', {
      'lat': 25,
      'lng': 121,
    });
    final second = await service.post('/external/weather', {
      'lng': 121,
      'lat': 25,
    });

    expect(second, first);
    expect(requests, hasLength(1));
  });
  test('simultaneous identical external reads share one invocation', () async {
    gate = Completer<void>();
    final service = ServiceCloudApi(client: client);

    final first = service.post('/external/geocode', {'query': 'Taipei'});
    final second = service.post('/external/geocode', {'query': 'Taipei'});
    while (requests.isEmpty) {
      await Future<void>.delayed(Duration.zero);
    }
    expect(requests, hasLength(1));

    gate!.complete();
    await Future.wait([first, second]);
    expect(requests, hasLength(1));
  });
  test('account mutations are never cached or combined', () async {
    final service = ServiceCloudApi(client: client);

    await service.post('/account/admin/create-user', {'email': 'a@test.dev'});
    await service.post('/account/admin/create-user', {'email': 'a@test.dev'});

    expect(requests, hasLength(2));
  });
  test(
    'stock route is rejected by non-stock transport before network',
    () async {
      await expectLater(
        ServiceCloudApi(client: client).get('stock/select'),
        throwsArgumentError,
      );
      expect(requests, isEmpty);
    },
  );
  test(
    'an old explicitly captured token cannot invoke after account switch',
    () async {
      await login(client, 'two');
      await expectLater(
        ServiceCloudApi(
          client: client,
        ).get('external/weather', bearerToken: 'token-one'),
        throwsA(isA<ServiceApiException>()),
      );
      expect(requests, isEmpty);
    },
  );
  test('old response is not delivered to a newly signed-in account', () async {
    gate = Completer<void>();
    final future = ServiceCloudApi(
      client: client,
    ).get('event/public_events_updated_today');
    final assertion = expectLater(future, throwsStateError);
    while (requests.isEmpty) {
      await Future<void>.delayed(Duration.zero);
    }
    await login(client, 'two');
    gate!.complete();
    await assertion;
  });
  test(
    'late old-account authentication failure cannot invalidate new session',
    () async {
      var reported = false;
      final subscription = AuthSessionGuard.failures.listen(
        (_) => reported = true,
      );
      gate = Completer<void>();
      status = 401;
      final future = ServiceCloudApi(
        client: client,
      ).get('event/public_events_updated_today');
      final assertion = expectLater(
        future,
        throwsA(isA<ServiceApiException>()),
      );
      while (requests.isEmpty) {
        await Future<void>.delayed(Duration.zero);
      }
      await login(client, 'two');
      gate!.complete();
      await assertion;
      await Future<void>.delayed(Duration.zero);
      expect(reported, isFalse);
      await subscription.cancel();
    },
  );
  test(
    'timeout is surfaced as a service error without a Render retry',
    () async {
      gate = Completer<void>();
      await expectLater(
        ServiceCloudApi(
          client: client,
          timeout: const Duration(milliseconds: 20),
        ).get('event/public_events_updated_today'),
        throwsA(isA<ServiceApiException>()),
      );
      expect(requests, hasLength(1));
      gate!.complete();
    },
  );
  test('Render path guard permits stock and rejects other routes', () {
    final transport = ServiceApi(
      'https://stock.example',
      allowedPathPrefixes: const ['stock/'],
    );
    expect(transport.buildUri('/stock/select').path, '/stock/select');
    for (final route in [
      'external/weather',
      'account/admin/create-user',
      'stock/../account',
      'stock/%2e%2e/account',
      'stock/\\../account',
      'https://elsewhere/stock',
    ]) {
      expect(() => transport.buildUri(route), throwsArgumentError);
    }
  });
  test('non-stock source files never use Render API transport', () {
    for (final entity
        in Directory('lib')
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.path.endsWith('.dart'))) {
      final path = entity.path.replaceAll('\\', '/');
      if (path == 'lib/utils/api.dart' || path.startsWith('lib/stock/')) {
        continue;
      }
      expect(
        entity.readAsStringSync(),
        isNot(contains('apiSupabase.')),
        reason: path,
      );
      expect(
        entity.readAsStringSync(),
        isNot(matches(RegExp(r'\bapi\.(get|post)\('))),
        reason: path,
      );
    }
  });
}
