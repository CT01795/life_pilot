import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:life_pilot/vendor/repository_vendor_initialization.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  late SupabaseClient client;
  var calls = 0;
  var status = 200;
  String? errorCode;
  Completer<void>? gate;
  setUp(() {
    calls = 0;
    status = 200;
    errorCode = null;
    gate = null;
    client = SupabaseClient(
      'https://example.supabase.co',
      'test-key',
      httpClient: MockClient((request) async {
        calls++;
        final waiting = gate;
        if (waiting != null) await waiting.future;
        return http.Response(
          jsonEncode(
            errorCode == null
                ? null
                : {'code': errorCode, 'message': 'rejected'},
          ),
          status,
          request: request,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
  });
  tearDown(() => client.dispose());
  test(
    'concurrent and later visits share only the latest successful session initialization',
    () async {
      final repository = RepositoryVendorInitialization(client);
      gate = Completer<void>();
      final first = repository.ensure(('a', 'session1'));
      final second = repository.ensure(('a', 'session1'));
      expect(identical(first, second), true);
      await Future<void>.delayed(Duration.zero);
      expect(calls, 1);
      gate!.complete();
      await Future.wait([first, second]);
      gate = null;
      await repository.ensure(('a', 'session1'));
      expect(calls, 1);
      await repository.ensure(('a', 'session2'));
      expect(calls, 2);
      await repository.ensure(('b', 'session2'));
      expect(calls, 3);
      await repository.ensure(('a', 'session1'));
      expect(calls, 4);
    },
  );
  for (final code in ['PGRST202', '42883', '42501']) {
    test('$code is never remembered as successful setup', () async {
      final repository = RepositoryVendorInitialization(client);
      status = 403;
      errorCode = code;
      if (code == '42501') {
        await expectLater(
          repository.ensure('a'),
          throwsA(isA<PostgrestException>()),
        );
      } else {
        await repository.ensure('a');
      }
      status = 200;
      errorCode = null;
      await repository.ensure('a');
      expect(calls, 2);
    });
  }
  test('no authenticated scope is not cached', () async {
    final repository = RepositoryVendorInitialization(client);
    await repository.ensure(null);
    await repository.ensure(null);
    expect(calls, 2);
  });
}
