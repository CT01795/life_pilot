import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:life_pilot/event/model_event_item.dart';
import 'package:life_pilot/utils/event_latln.dart';
import 'package:life_pilot/utils/supabase.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> _login(SupabaseClient client) => client.auth.setInitialSession(
  jsonEncode({
    'access_token': 'token',
    'refresh_token': 'refresh',
    'expires_in': 3600,
    'token_type': 'bearer',
    'user': {
      'id': '00000000-0000-4000-8000-000000000001',
      'email': 'person@example.com',
      'aud': 'authenticated',
      'role': 'authenticated',
      'user_metadata': <String, dynamic>{},
      'app_metadata': <String, dynamic>{},
      'created_at': '2026-01-01T00:00:00Z',
    },
  }),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('single address resolves both cache layers with one RPC', () async {
    final requests = <http.Request>[];
    final client = SupabaseClient(
      'https://example.supabase.co',
      'test-key',
      httpClient: MockClient((request) async {
        requests.add(request);
        return http.Response(
          jsonEncode({'lat': 25.04, 'lng': 121.56}),
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      }),
    );
    addTearDown(client.dispose);
    await _login(client);
    supabase = client;

    final result = await ClusterItem.getLatLngFromAddressCommon(
      locationDisplay: '台北市．信義區',
    );

    expect(result, {'lat': 25.04, 'lng': 121.56});
    expect(requests, hasLength(1));
    expect(
      requests.single.url.path,
      endsWith('/rpc/life_pilot_resolve_cached_address'),
    );
  });

  test('address cache lookup batches one hundred events per RPC', () async {
    final requests = <http.Request>[];
    final client = SupabaseClient(
      'https://example.supabase.co',
      'test-key',
      httpClient: MockClient((request) async {
        requests.add(request);
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        final queries = body['p_queries'] as List;
        return http.Response(
          jsonEncode(
            List.generate(
              queries.length,
              (index) => {'lat': 25.0 + index, 'lng': 121.0 + index},
            ),
          ),
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      }),
    );
    addTearDown(client.dispose);
    supabase = client;
    final events = List.generate(
      101,
      (index) => EventItem(
        id: '$index',
        city: 'Taipei $index',
        location: 'Location $index',
      ),
    );

    final result = await ClusterItem.getLatLngFromAddressItems(events);

    expect(requests, hasLength(2));
    expect(
      requests.every(
        (request) => request.url.path.endsWith('/rpc/search_lat_lng_batch'),
      ),
      isTrue,
    );
    expect(
      (jsonDecode(requests.first.body)['p_queries'] as List),
      hasLength(100),
    );
    expect((jsonDecode(requests.last.body)['p_queries'] as List), hasLength(1));
    expect(result.first.lat, 25);
    expect(result.first.lng, 121);
    expect(result.last.lat, 25);
    expect(result.last.lng, 121);
  });
}
