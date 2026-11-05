import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:life_pilot/auth/controller_auth.dart';
import 'package:life_pilot/auth/controller_account_deletion_queue.dart';
import 'package:life_pilot/auth/model_account_deletion_page.dart';
import 'package:life_pilot/auth/repository_account_deletion.dart';
import 'package:life_pilot/auth/widgets_admin_account_deletion_queue.dart';
import 'package:life_pilot/l10n/app_localizations.dart';

class _Auth extends ControllerAuth {
  String account = 'admin@example.com';
  bool admin = true;
  @override
  String get currentAccount => account;
  @override
  bool get isSysAdmin => admin;
  void revoke() {
    admin = false;
    notifyListeners();
  }
}

Map<String, dynamic> row(int id, [String status = 'pending']) => {
  'id': '$id',
  'email': 'user$id@example.com',
  'status': status,
  'requested_at': '2026-11-01T00:00:00Z',
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SupabaseClient client;
  late List<http.Request> requests;
  var missing = false, denied = false;
  setUp(() async {
    requests = [];
    missing = false;
    denied = false;
    client = SupabaseClient(
      'https://example.supabase.co',
      'key',
      httpClient: MockClient((request) async {
        requests.add(request);
        final page = request.url.path.endsWith('_page');
        return http.Response(
          jsonEncode(
            denied
                ? {'code': '42501', 'message': 'denied'}
                : missing && page
                ? {'code': 'PGRST202', 'message': 'missing'}
                : page
                ? {'rows': List.generate(51, row)}
                : List.generate(51, row),
          ),
          denied
              ? 403
              : missing && page
              ? 404
              : 200,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      }),
    );
    await client.auth.setInitialSession(
      jsonEncode({
        'access_token': 'token',
        'token_type': 'bearer',
        'user': {
          'id': 'admin',
          'email': 'admin@example.com',
          'app_metadata': {},
          'user_metadata': {},
          'aud': 'authenticated',
          'created_at': '2026-01-01T00:00:00Z',
        },
      }),
    );
  });
  tearDown(() => client.dispose());

  test('page sends bounded cursor and validates pending statuses', () async {
    final repo = RepositoryAccountDeletion(client: client);
    final first = await repo.adminPage();
    expect(first.rows, hasLength(50));
    expect(first.hasMore, isTrue);
    await repo.adminPage(after: first.rows.last.cursor);
    final body = jsonDecode(requests.last.body) as Map;
    expect(body['p_limit'], 50);
    expect(body['p_after']['id'], '49');
    expect(
      () => AccountDeletionRequest.fromJson(row(1, 'completed')),
      throwsFormatException,
    );
  });
  test('missing pending page RPC does not query the old list', () async {
    missing = true;
    await expectLater(
      RepositoryAccountDeletion(client: client).adminPage(),
      throwsA(
        isA<PostgrestException>().having((e) => e.code, 'code', 'PGRST202'),
      ),
    );
    expect(requests, hasLength(1));
  });
  test('permission failure never falls back to a different read', () async {
    denied = true;
    await expectLater(
      RepositoryAccountDeletion(client: client).adminPage(),
      throwsA(isA<PostgrestException>()),
    );
    expect(requests, hasLength(1));
  });

  test(
    'successful actions remove only that row without reloading; failure stays retryable',
    () async {
      final auth = _Auth();
      var loads = 0, approvals = 0, cancellations = 0;
      var fail = true;
      final c = ControllerAccountDeletionQueue(
        auth: auth,
        load: ({after, required offset}) async {
          loads++;
          return AccountDeletionPage.fromRows([
            row(1),
            row(2, 'cancel_pending'),
          ]);
        },
        approve: (id) async {
          approvals++;
          if (fail) throw StateError('failed');
        },
        confirmCancellation: (id) async {
          cancellations++;
        },
      );
      addTearDown(c.dispose);
      addTearDown(auth.dispose);
      expect(loads, 0);
      await c.load();
      final request = c.rows.first;
      expect(await c.process(request), false);
      expect(c.rows, hasLength(2));
      expect(approvals, 1);
      fail = false;
      expect(await c.process(request), true);
      expect(c.rows, hasLength(1));
      expect(loads, 1);
      expect(await c.process(request), isNull);
      expect(await c.process(c.rows.single), true);
      expect(cancellations, 1);
    },
  );
  test(
    'disabled-account removal shifts next offset and concurrent actions are blocked',
    () async {
      final auth = _Auth();
      final gate = Completer<void>();
      final offsets = <int>[];
      final c = ControllerAccountDeletionQueue(
        auth: auth,
        load: ({after, required offset}) async {
          offsets.add(offset);
          return AccountDeletionPage.fromRows(
            List.generate(51, row),
            offsetBased: true,
          );
        },
        approve: (id) => gate.future,
        confirmCancellation: (id) async {},
      );
      addTearDown(c.dispose);
      addTearDown(auth.dispose);
      await c.load();
      final action = c.process(c.rows.first);
      expect(await c.process(c.rows.last), isNull);
      gate.complete();
      await action;
      await c.load(more: true);
      expect(offsets, [0, 49]);
    },
  );
  test('role change clears queue and ignores old page completion', () async {
    final auth = _Auth();
    final gate = Completer<AccountDeletionPage>();
    var actions = 0;
    final c = ControllerAccountDeletionQueue(
      auth: auth,
      load: ({after, required offset}) => gate.future,
      approve: (id) async {
        actions++;
      },
      confirmCancellation: (id) async {
        actions++;
      },
    );
    addTearDown(c.dispose);
    addTearDown(auth.dispose);
    final load = c.load();
    auth.revoke();
    gate.complete(AccountDeletionPage.fromRows([row(1)]));
    await load;
    expect(c.rows, isEmpty);
    expect(c.loading, isFalse);
    expect(await c.process(AccountDeletionRequest.fromJson(row(1))), isNull);
    expect(actions, 0);
  });
  test('append failure retains rows and retries the same cursor', () async {
    final auth = _Auth();
    var fail = true;
    final offsets = <int>[];
    final c = ControllerAccountDeletionQueue(
      auth: auth,
      load: ({after, required offset}) async {
        offsets.add(offset);
        if (offset > 0 && fail) throw StateError('network');
        return AccountDeletionPage.fromRows(
          offset == 0 ? List.generate(51, row) : [row(50)],
        );
      },
      approve: (id) async {},
      confirmCancellation: (id) async {},
    );
    addTearDown(c.dispose);
    addTearDown(auth.dispose);
    await c.load();
    await c.load(more: true);
    expect(c.rows, hasLength(50));
    expect(c.loadError, isNotNull);
    fail = false;
    await c.load(more: c.retryMore);
    expect(c.rows, hasLength(51));
    expect(offsets, [0, 50, 50]);
    expect(c.loadError, isNull);
  });
  test(
    'revoked admin ignores late action completion without refetch',
    () async {
      final auth = _Auth();
      final gate = Completer<void>();
      var loads = 0;
      final c = ControllerAccountDeletionQueue(
        auth: auth,
        load: ({after, required offset}) async {
          loads++;
          return AccountDeletionPage.fromRows([row(1)]);
        },
        approve: (id) => gate.future,
        confirmCancellation: (id) async {},
      );
      addTearDown(c.dispose);
      addTearDown(auth.dispose);
      await c.load();
      final action = c.process(c.rows.single);
      auth.revoke();
      gate.complete();
      expect(await action, isNull);
      expect(c.rows, isEmpty);
      expect(c.working, isFalse);
      expect(loads, 1);
    },
  );
  testWidgets('collapsed queue makes no query; expansion loads once', (
    tester,
  ) async {
    final auth = _Auth();
    addTearDown(auth.dispose);
    await tester.pumpWidget(
      ChangeNotifierProvider<ControllerAuth>.value(
        value: auth,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SingleChildScrollView(
              child: AdminAccountDeletionQueue(
                repository: RepositoryAccountDeletion(client: client),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(requests, isEmpty);
    await tester.tap(find.byType(ExpansionTile));
    await tester.pumpAndSettle();
    expect(requests, hasLength(1));
    expect(find.text('user0@example.com'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
