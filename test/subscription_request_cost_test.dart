import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:life_pilot/subscription/repository_subscription_counts.dart';
import 'package:life_pilot/subscription/service_subscription.dart';
import 'package:life_pilot/utils/supabase.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SupabaseClient client;
  late List<http.Request> requests;
  var fail = false;
  var count = 1501;
  setUp(() {
    requests = [];
    fail = false;
    count = 1501;
    client = SupabaseClient(
      'https://example.supabase.co',
      'test-key',
      httpClient: MockClient((request) async {
        requests.add(request);
        if (fail) {
          return http.Response(
            jsonEncode({'code': '42501', 'message': 'denied'}),
            403,
            request: request,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response(
          request.method == 'HEAD' ? '' : 'null',
          200,
          request: request,
          headers: {
            'content-type': 'application/json',
            'content-range': '*/$count',
          },
        );
      }),
    );
    supabase = client;
  });
  tearDown(() => client.dispose());

  test(
    'usage uses two exact HEAD counts without downloading IDs or row limits',
    () async {
      final repository = RepositorySubscriptionCounts(client);
      final result = await repository.readRecommendations(
        account: ' Owner@Example.com ',
        now: DateTime(2026, 10, 30),
      );
      expect(result, [1501, 1501]);
      expect(requests, hasLength(2));
      for (final request in requests) {
        expect(request.method, 'HEAD');
        expect(request.headers['Prefer'], contains('count=exact'));
        expect(
          request.url.queryParameters['account'],
          'ilike.owner@example.com',
        );
        expect(
          request.url.queryParameters['or'],
          '(end_date.gte.2026-10-30,start_date.gte.2026-10-30)',
        );
        expect(request.url.queryParameters.containsKey('select'), false);
      }
    },
  );
  test('mutation follow-up reads fresh counts including zero', () async {
    final repository = RepositorySubscriptionCounts(client);
    await repository.readRecommendations(
      account: 'a@b.com',
      now: DateTime(2026),
    );
    count = 0;
    expect(
      await repository.readRecommendations(
        account: 'a@b.com',
        now: DateTime(2026),
      ),
      [0, 0],
    );
    expect(requests, hasLength(4));
  });
  test('blank owner never sends an unscoped query', () async {
    await expectLater(
      RepositorySubscriptionCounts(
        client,
      ).readRecommendations(account: ' ', now: DateTime(2026)),
      throwsArgumentError,
    );
    expect(requests, isEmpty);
  });
  test('permission failures are not presented as zero usage', () async {
    fail = true;
    await expectLater(
      RepositorySubscriptionCounts(
        client,
      ).readRecommendations(account: 'a@b.com', now: DateTime(2026)),
      throwsA(isA<PostgrestException>()),
    );
  });
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
          endsWith('/admin_create_subscription_pricing_version'),
        );
        expect(
          jsonDecode(requests.single.body)['p_quarterly_price_twd'],
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
      final params = jsonDecode(requests.single.body) as Map;
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
