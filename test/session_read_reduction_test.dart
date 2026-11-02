import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:life_pilot/apps/service_module.dart';
import 'package:life_pilot/auth/repository_account_deletion.dart';
import 'package:life_pilot/feedback/service_feedback.dart';
import 'package:life_pilot/local_storage/service_local_data_transfer.dart';
import 'package:life_pilot/utils/repository_session_reads.dart';
import 'package:life_pilot/utils/service/export/repository_personal_export_rows.dart';
import 'package:life_pilot/utils/supabase.dart';

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
  Object? payload;
  var status = 200;
  setUp(() async {
    requests = [];
    gate = null;
    payload = [];
    status = 200;
    client = SupabaseClient(
      'https://example.supabase.co',
      'public-key',
      httpClient: MockClient((request) async {
        requests.add(request);
        final pending = gate, body = payload, code = status;
        if (pending != null) await pending.future;
        return http.Response(
          jsonEncode(body),
          code,
          request: request,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    supabase = client;
    await login(client, 'one');
  });
  tearDown(() => client.dispose());

  final operations = <String, Future<Object?> Function()>{
    'module admin': () =>
        ServiceModule().loadUserModulesAsAdmin('one@example.com'),
    'module own': () =>
        ServiceModule().loadModulesFromServer('one@example.com'),
    'feedback list': () => ServiceFeedback().loadFeedback(
      dateFrom: DateTime(2026),
      dateTo: DateTime(2027),
    ),
    'Excel pages': () => RepositoryPersonalExportRows().read('one@example.com'),
    'deletion own': () => RepositoryAccountDeletion().ownRequest(),
    'deletion admin': () => RepositoryAccountDeletion().adminRequests(),
    'retention preview': () =>
        ServiceLocalDataTransfer().cloudAnswerRetention(),
  };
  for (final operation in operations.entries) {
    test(
      '${operation.key}: simultaneous reads share, later read stays fresh',
      () async {
        if (operation.key == 'retention preview') payload = {'days': 0};
        gate = Completer<void>();
        final a = operation.value(), b = operation.value();
        await Future<void>.delayed(Duration.zero);
        expect(requests, hasLength(1));
        gate!.complete();
        await Future.wait([a, b]);
        gate = null;
        await operation.value();
        expect(requests, hasLength(2));
      },
    );
  }
  test('different module targets do not share a response', () async {
    gate = Completer<void>();
    final a = ServiceModule().loadUserModulesAsAdmin('one@example.com');
    final b = ServiceModule().loadUserModulesAsAdmin('two@example.com');
    await Future<void>.delayed(Duration.zero);
    expect(requests, hasLength(2));
    gate!.complete();
    await Future.wait([a, b]);
  });
  test(
    'module writes invalidate active reads; old completion cannot replace new data',
    () async {
      payload = [
        {'module_key': 'points'},
      ];
      gate = Completer<void>();
      final oldGate = gate!;
      final old = ServiceModule().loadUserModulesAsAdmin('one@example.com');
      final checked = expectLater(old, throwsStateError);
      await Future<void>.delayed(Duration.zero);
      gate = null;
      await ServiceModule().saveUserModulesAsAdmin(
        account: 'one@example.com',
        moduleKeys: ['game'],
      );
      payload = [
        {'module_key': 'game'},
      ];
      expect(await ServiceModule().loadUserModulesAsAdmin('one@example.com'), [
        'game',
      ]);
      oldGate.complete();
      await checked;
      expect(requests, hasLength(3));
    },
  );
  test(
    'deletion writes invalidate both list kinds without automatic retry',
    () async {
      gate = Completer<void>();
      final oldGate = gate!;
      final old = RepositoryAccountDeletion().ownRequest();
      final checked = expectLater(old, throwsStateError);
      await Future<void>.delayed(Duration.zero);
      gate = null;
      await RepositoryAccountDeletion().cancel();
      payload = [
        {'id': 'r', 'status': 'cancel_pending'},
      ];
      expect(
        (await RepositoryAccountDeletion().ownRequest())?['status'],
        'cancel_pending',
      );
      oldGate.complete();
      await checked;
      expect(
        requests.where(
          (r) => r.url.path.endsWith('cancel_account_deletion_request'),
        ),
        hasLength(1),
      );
    },
  );
  test(
    'feedback update prevents pending metadata from becoming current',
    () async {
      final reads = RepositorySessionReads(client);
      final pending = Completer<int>();
      final old = reads.read('feedback', 'example', () => pending.future);
      final checked = expectLater(old, throwsStateError);
      await ServiceFeedback().sendFeedback(
        account: 'one@example.com',
        subject: 'test',
        content: 'test',
      );
      pending.complete(1);
      await checked;
    },
  );
  test(
    'session switch rejects old private results and makes a separate read',
    () async {
      final repo = RepositorySessionReads(client);
      final pending = Completer<int>();
      final old = repo.read('private', 'same', () => pending.future);
      final checked = expectLater(old, throwsStateError);
      await login(client, 'two');
      expect(await repo.read('private', 'same', () async => 2), 2);
      pending.complete(1);
      await checked;
    },
  );
  test(
    'failed reads release their slot and retry instead of caching errors',
    () async {
      payload = {'code': '42501', 'message': 'denied'};
      status = 403;
      await expectLater(
        RepositoryAccountDeletion().ownRequest(),
        throwsA(isA<PostgrestException>()),
      );
      payload = [];
      status = 200;
      expect(await RepositoryAccountDeletion().ownRequest(), isNull);
      expect(requests, hasLength(2));
    },
  );
  testWidgets('timeout permits retry and observes a late underlying error', (
    tester,
  ) async {
    final reads = RepositorySessionReads(client), pending = Completer<int>();
    final old = reads.read(
      'slow',
      'key',
      () => pending.future,
      timeout: const Duration(seconds: 1),
    );
    final checked = expectLater(old, throwsA(isA<TimeoutException>()));
    await tester.pump(const Duration(seconds: 2));
    await checked;
    expect(await reads.read('slow', 'key', () async => 2), 2);
    pending.completeError(StateError('late'));
    await tester.pump();
  });
  test('signed-out requests never reach the database', () async {
    await client.auth.signOut(scope: SignOutScope.local);
    requests.clear();
    await expectLater(
      ServiceModule().loadUserModulesAsAdmin('one@example.com'),
      throwsStateError,
    );
    expect(requests, isEmpty);
  });
  test('shared export rows cannot be mutated by a consumer', () async {
    payload = [
      {'table_name': 'memory_trace', 'id': 'm', 'value': 23.4},
    ];
    final rows = await RepositoryPersonalExportRows().read('one@example.com');
    expect(() => rows.clear(), throwsUnsupportedError);
    expect(() => rows.single['value'] = 0, throwsUnsupportedError);
  });
}
