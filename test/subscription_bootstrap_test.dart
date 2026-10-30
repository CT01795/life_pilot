import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:life_pilot/subscription/repository_subscription_bootstrap.dart';
import 'package:life_pilot/subscription/service_subscription.dart';
import 'package:life_pilot/utils/supabase.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SupabaseClient client;
  late List<http.Request> requests;
  var status = 200;
  dynamic payload;
  setUp(() {
    requests = [];
    status = 200;
    payload = {
      'status': {'plan': 'free', 'status': 'active', 'storage_plan': 'cloud'},
      'usage': [
        {'resource': 'calendar_events', 'used': 2, 'quota': 7},
      ],
      'entitlements': [],
      'cumulative_quotas': {'calendar_events': 7},
      'recommendation_counts': [3, 1],
    };
    client = SupabaseClient(
      'https://example.supabase.co',
      'test-key',
      httpClient: MockClient((request) async {
        requests.add(request);
        return http.Response(
          jsonEncode(payload),
          status,
          request: request,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    supabase = client;
  });
  tearDown(() => client.dispose());
  test(
    'bundled empty promotion list is authoritative and survives usage copies',
    () async {
      payload['quota_free_periods'] = [];
      final snapshot = await ServiceSubscription().fetchMyUsage();
      expect(snapshot.promotionPeriods, isEmpty);
      expect(snapshot.copyWithUsage({}).promotionPeriods, isEmpty);
      expect(requests, hasLength(1));
    },
  );
  test('bundled promotion targets are normalized and immutable', () async {
    payload['quota_free_periods'] = [
      {
        'period_id': 'one',
        'period_name': 'Test',
        'starts_at': '2026-10-01T00:00:00Z',
        'ends_at': '2026-12-01T00:00:00Z',
        'enabled': true,
        'is_active': true,
        'reminder_days': 3,
        'target_accounts': [' A@Example.com ', ''],
      },
    ];
    final snapshot = await ServiceSubscription().fetchMyUsage();
    final period = snapshot.promotionPeriods!.single;
    expect(period.targetAccounts, ['a@example.com']);
    expect(period.reminderDays, 3);
    expect(() => period.targetAccounts.clear(), throwsUnsupportedError);
    expect(requests, hasLength(1));
  });

  test('configured free allowance is read in one round trip', () async {
    final snapshot = await ServiceSubscription().fetchMyUsage();
    expect(snapshot.configurationMissing, false);
    expect(snapshot['calendar_events']!.quota, 7);
    expect(snapshot['calendar_events']!.used, 2);
    expect(requests, hasLength(1));
    expect(
      requests.single.url.path,
      endsWith('/get_my_subscription_bootstrap'),
    );
  });
  for (final mode in ['cloud', 'local']) {
    test(
      'missing $mode allowance explicitly returns read-only without follow-up reads',
      () async {
        payload['status'] = {
          'plan': 'unconfigured',
          'status': 'configuration_missing',
        };
        final snapshot = await ServiceSubscription().fetchMyUsage(
          storagePlan: mode,
        );
        expect(snapshot.configurationMissing, true);
        expect(snapshot.storagePlan, mode);
        expect(snapshot.copyWithUsage({}).configurationMissing, true);
        expect(requests, hasLength(1));
        expect(jsonDecode(requests.single.body), {'p_storage_plan': mode});
      },
    );
  }
  test(
    'zero configured quota is not confused with missing configuration',
    () async {
      payload['cumulative_quotas']['calendar_events'] = 0;
      final result = await ServiceSubscription().fetchMyUsage();
      expect(result.configurationMissing, false);
      expect(result['calendar_events']!.quota, 0);
    },
  );
  test(
    'a later request after subscription changes never uses a cached decision',
    () async {
      expect(
        (await ServiceSubscription().fetchMyUsage()).configurationMissing,
        false,
      );
      payload['status']['status'] = 'configuration_missing';
      expect(
        (await ServiceSubscription().fetchMyUsage()).configurationMissing,
        true,
      );
      expect(requests, hasLength(2));
    },
  );
  test(
    'only an undeployed RPC enables legacy reads; capability is client-scoped',
    () async {
      status = 404;
      payload = {'code': 'PGRST202', 'message': 'not deployed'};
      final repository = RepositorySubscriptionBootstrap(client);
      expect(await repository.read('cloud'), null);
      expect(await repository.read('local'), null);
      expect(requests, hasLength(1));
    },
  );
  for (final code in ['42501', 'P0001', '42P01']) {
    test('$code cannot bypass a failed bootstrap via legacy queries', () async {
      status = 403;
      payload = {'code': code, 'message': 'rejected'};
      await expectLater(
        ServiceSubscription().fetchMyUsage(),
        throwsA(isA<PostgrestException>()),
      );
      expect(requests, hasLength(1));
    });
  }
}
