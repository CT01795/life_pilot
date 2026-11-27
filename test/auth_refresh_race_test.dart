import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:life_pilot/auth/controller_auth.dart';
import 'package:life_pilot/local_storage/local_data_store.dart';
import 'package:life_pilot/utils/supabase.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _user = {
  'id': 'refresh-owner',
  'email': 'refresh@example.com',
  'aud': 'authenticated',
  'created_at': '2026-01-01T00:00:00Z',
};

Map<String, Object?> _usage(int used) => {
  'quota_free_periods': [],
  'usage': [
    {'resource': 'calendar_events', 'used': used, 'quota': 30},
  ],
  'status': {'plan': 'free', 'status': 'active'},
  'entitlements': [],
  'cumulative_quotas': {'recommended_events': 5, 'recommended_attractions': 2},
  'recommendation_counts': [0, 0],
};

Future<void> _flush() => Future<void>.delayed(Duration.zero);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ControllerAuth auth;
  late List<Completer<bool>> checks;
  late List<Completer<({int status, Object body})>> usages;

  setUp(() async {
    checks = [];
    usages = [];
    final client = SupabaseClient(
      'https://example.supabase.co',
      'test-key',
      httpClient: MockClient((request) async {
        final endpoint = request.url.pathSegments.last;
        var status = 200;
        Object body;
        switch (endpoint) {
          case 'user':
            body = _user;
          case 'is_my_life_pilot_account_disabled':
            final gate = Completer<bool>();
            checks.add(gate);
            body = await gate.future;
          case 'get_my_subscription_bootstrap':
            final gate = Completer<({int status, Object body})>();
            usages.add(gate);
            final response = await gate.future;
            status = response.status;
            body = response.body;
          default:
            throw StateError('Unexpected request: ${request.url.path}');
        }
        return http.Response(
          jsonEncode(body),
          status,
          request: request,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    supabase = client;
    await client.auth.setInitialSession(
      jsonEncode({
        'access_token': 'token',
        'token_type': 'bearer',
        'user': _user,
      }),
    );
    final db = await databaseFactoryMemory.openDatabase('auth-refresh');
    auth = ControllerAuth(localStore: LocalDataStore.withDatabase(db));
    addTearDown(() async {
      auth.dispose();
      await client.dispose();
      await db.close();
    });
  });

  Future<void> until(bool Function() done) async {
    for (var i = 0; i < 100 && !done(); i++) {
      await _flush();
    }
    expect(done(), isTrue);
  }

  test(
    'queued verification blocks startup until the follow-up succeeds',
    () async {
      final startup = auth.checkLoginStatus();
      await until(() => checks.length == 1);
      final forced = auth.validateCurrentAccount(force: true);
      expect(auth.validateCurrentAccount(force: true), same(forced));
      expect(checks, hasLength(1));
      checks.first.complete(false);
      await until(() => checks.length == 2);
      expect(auth.accountVerificationBlocked, isTrue);
      expect(usages, isEmpty);
      checks.last.complete(false);
      expect(await forced, AccountValidationResult.valid);
      await startup;
      await until(() => usages.isNotEmpty);
      usages.single.complete((status: 200, body: _usage(1)));
      await until(() => auth.subscription['calendar_events']?.used == 1);
      expect(auth.accountVerificationBlocked, isFalse);
    },
  );

  for (final oldFails in [false, true]) {
    test(
      'late subscription response cannot replace fresher data (failure=$oldFails)',
      () async {
        final startup = auth.checkLoginStatus();
        await until(() => checks.isNotEmpty);
        checks.single.complete(false);
        await startup;
        await until(() => usages.isNotEmpty);
        final refresh = auth.refreshSubscriptionUsage();
        await until(() => usages.length == 2);
        usages.last.complete((status: 200, body: _usage(8)));
        await refresh;
        usages.first.complete(
          oldFails
              ? (status: 400, body: {'message': 'old request failed'})
              : (status: 200, body: _usage(2)),
        );
        await _flush();
        expect(auth.subscription['calendar_events']?.used, 8);
      },
    );
  }
}
