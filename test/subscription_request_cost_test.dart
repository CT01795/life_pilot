import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:life_pilot/subscription/service_subscription.dart';
import 'package:life_pilot/utils/supabase.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SupabaseClient client;
  late List<http.Request> requests;
  setUp(() {
    requests = [];
    client = SupabaseClient(
      'https://example.supabase.co',
      'test-key',
      httpClient: MockClient((request) async {
        requests.add(request);
        return http.Response(
          request.method == 'HEAD' ? '' : 'null',
          200,
          request: request,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    supabase = client;
  });
  tearDown(() => client.dispose());

  for (final price in [0, 129]) {
    test(
      'first pricing version with price $price needs no previous version read',
      () async {
        await ServiceSubscription().createPricingVersionAsAdmin(
          name: 'First',
          storagePlan: 'cloud',
          effectiveAt: DateTime.utc(2026),
          quarterlyPrice: price,
          quotas: quotas,
        );
        expect(requests, hasLength(1));
        expect(
          requests.single.url.path,
          endsWith('/admin_save_pricing_version'),
        );
        expect(
          jsonDecode(
            requests.single.body,
          )['p_payload']['p_quarterly_price_twd'],
          price,
        );
      },
    );
  }
  test(
    'updating a version includes the same public content quota parameters as creation',
    () async {
      await ServiceSubscription().updatePricingVersionAsAdmin(
        pricingVersionId: 'version',
        name: 'First',
        storagePlan: 'cloud',
        effectiveAt: DateTime.utc(2026),
        quarterlyPrice: 129,
        quotas: quotas,
      );
      final params = jsonDecode(requests.single.body)['p_payload'] as Map;
      expect(params['p_recommended_event_quota'], 20);
      expect(params['p_recommended_attraction_quota'], 5);
    },
  );
}

const quotas = {
  'calendar': 300,
  'accounting': 300,
  'point': 300,
  'memory': 300,
  'game': 500,
  'share': 5,
  'event': 20,
  'attraction': 5,
  'image': 10,
  'answerDays': 365,
};
