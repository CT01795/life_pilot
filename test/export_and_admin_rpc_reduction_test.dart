import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:life_pilot/subscription/repository_admin_subscription_overview.dart';
import 'package:life_pilot/utils/service/export/repository_personal_export_rows.dart';

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
  var missing = false, denied = false, malformed = false;
  setUp(() async {
    requests = [];
    gate = null;
    missing = false;
    denied = false;
    malformed = false;
    client = SupabaseClient(
      'https://example.supabase.co',
      'key',
      httpClient: MockClient((request) async {
        requests.add(request);
        final path = request.url.path;
        final modern =
            path.endsWith('admin_get_user_subscription_overview') ||
            path.endsWith('export_my_personal_excel_rows');
        Object? body;
        var code = 200;
        if (modern && (missing || denied)) {
          body = {
            'code': denied ? '42501' : 'PGRST202',
            'message': denied ? 'denied' : 'not deployed',
          };
          code = denied ? 403 : 404;
        } else if (path.endsWith('admin_get_user_subscription_overview')) {
          body = {
            'subscription': {'plan': 'plus'},
            'entitlements': malformed
                ? null
                : [
                    {'id': '1'},
                    {'id': '2'},
                  ],
          };
        } else if (path.endsWith('admin_get_user_subscription')) {
          body = [
            {'plan': 'plus'},
          ];
        } else if (path.endsWith('admin_get_user_subscription_entitlements')) {
          body = [
            {'id': '1'},
            {'id': '2'},
          ];
        } else {
          final offset = int.parse(
            request.url.queryParameters['offset'] ?? '0',
          );
          body = offset > 1000
              ? []
              : offset == 1000
              ? [
                  {'table_name': 'memory_trace', 'id': 'last'},
                ]
              : List.generate(
                  1000,
                  (i) => {'table_name': 'memory_trace', 'id': i.toString()},
                );
        }
        if (path.endsWith('export_my_personal_excel_rows') && code == 200) {
          body = (body as List)
              .map(
                (row) => {
                  'table_name': row['table_name'],
                  'record': Map<String, dynamic>.from(row as Map)
                    ..remove('table_name'),
                },
              )
              .toList();
        }
        final pending = gate;
        if (pending != null) {
          await pending.future;
        }
        return http.Response(
          jsonEncode(body),
          code,
          request: request,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    await login(client, 'one');
  });
  tearDown(() => client.dispose());
  test('admin lookup is one request and retains every subscription', () async {
    final result = await RepositoryAdminSubscriptionOverview(
      client,
    ).read(' One@example.com ');
    expect(result.subscription?['plan'], 'plus');
    expect(result.entitlements, hasLength(2));
    expect(requests, hasLength(1));
    expect(jsonDecode(requests.single.body), {'p_email': 'one@example.com'});
    expect(() => result.entitlements.clear(), throwsUnsupportedError);
  });
  test(
    'only missing admin RPC enables two legacy reads; later deployment is detected',
    () async {
      missing = true;
      expect(
        (await RepositoryAdminSubscriptionOverview(
          client,
        ).read('one@example.com')).entitlements,
        hasLength(2),
      );
      expect(requests, hasLength(3));
      missing = false;
      await RepositoryAdminSubscriptionOverview(client).read('one@example.com');
      expect(requests, hasLength(4));
    },
  );
  test('admin permission failure never enables legacy queries', () async {
    denied = true;
    await expectLater(
      RepositoryAdminSubscriptionOverview(client).read('one@example.com'),
      throwsA(isA<PostgrestException>()),
    );
    expect(requests, hasLength(1));
  });
  test(
    'malformed overview remains an error rather than an empty subscription list',
    () async {
      malformed = true;
      await expectLater(
        RepositoryAdminSubscriptionOverview(client).read('one@example.com'),
        throwsFormatException,
      );
      expect(requests, hasLength(1));
    },
  );
  test(
    'admin response from old session is discarded before any fallback',
    () async {
      missing = true;
      gate = Completer<void>();
      final request = RepositoryAdminSubscriptionOverview(
        client,
      ).read('one@example.com');
      final checked = expectLater(request, throwsStateError);
      await Future<void>.delayed(Duration.zero);
      await login(client, 'two');
      gate!.complete();
      await checked;
      expect(requests, hasLength(1));
    },
  );
  for (final legacy in [false, true]) {
    test('Excel all pages complete (legacy=$legacy)', () async {
      missing = legacy;
      final rows = await RepositoryPersonalExportRows(
        client: client,
      ).read('one@example.com');
      expect(rows, hasLength(1001));
      expect(rows.last['id'], 'last');
      expect(requests, hasLength(legacy ? 4 : 3));
      if (!legacy) {
        expect(
          requests.every(
            (r) => r.url.path.endsWith('export_my_personal_excel_rows'),
          ),
          isTrue,
        );
      }
      expect(requests.last.url.queryParameters['offset'], '1001');
    });
  }
  test(
    'Excel denial never retries complete export with different permissions',
    () async {
      denied = true;
      await expectLater(
        RepositoryPersonalExportRows(client: client).read('one@example.com'),
        throwsA(isA<PostgrestException>()),
      );
      expect(requests, hasLength(1));
    },
  );
}
