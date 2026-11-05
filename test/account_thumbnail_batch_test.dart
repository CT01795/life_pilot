import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:life_pilot/accounting/repository_account_image.dart';
import 'package:life_pilot/local_storage/local_data_store.dart';
import 'package:life_pilot/utils/supabase.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('visible cards share one cloud thumbnail projection', () async {
    final requests = <http.Request>[];
    var batchInstalled = true;
    var missingColumn = false;
    final started = Completer<void>();
    final release = Completer<void>();
    final client = SupabaseClient(
      'https://example.supabase.co',
      'test-key',
      httpClient: MockClient((request) async {
        requests.add(request);
        if (missingColumn) {
          return http.Response(
            '{"code":"42703","message":"missing thumbnail column"}',
            400,
            request: request,
            headers: {'content-type': 'application/json'},
          );
        }
        if (request.url.queryParameters['id']?.contains('held') == true &&
            !started.isCompleted) {
          started.complete();
          await release.future;
        }
        final rpc = request.url.pathSegments.last;
        final missing =
            rpc == 'read_my_shared_ledger_thumbnails' && !batchInstalled;
        return http.Response(
          missing
              ? '{"code":"PGRST202","message":"missing"}'
              : rpc.startsWith('read_my_shared_ledger_')
              ? '{}'
              : '[]',
          missing ? 404 : 200,
          request: request,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    addTearDown(client.dispose);
    supabase = client;
    await client.auth.setInitialSession(
      jsonEncode({
        'access_token': 'token-test',
        'token_type': 'bearer',
        'user': {
          'id': 'test',
          'email': 'a@example.com',
          'aud': 'authenticated',
          'created_at': '2026-01-01T00:00:00Z',
        },
      }),
    );
    Future<Object?> load(String id) => const RepositoryAccountImage().read(
      table: 'accounting_account',
      accountId: id,
      owner: 'a@example.com',
      thumbnail: true,
      storage: DataStorageLocation.cloud,
    );
    expect(await Future.wait([load('a'), load('b'), load('a')]), [
      null,
      null,
      null,
    ]);
    expect(requests, hasLength(1));
    final query = requests.single.url.queryParameters;
    expect(query['select'], 'id,thumbnail_base64');
    expect(query['id'], allOf(contains('a'), contains('b')));
    expect(query['created_by'], 'eq.a@example.com');
    missingColumn = true;
    requests.clear();
    await expectLater(load('missing'), throwsA(isA<PostgrestException>()));
    expect(requests, hasLength(1));
    requests.clear();
    await expectLater(
      RepositoryAccountImage.writeCloud('accounting_account', 'a', {
        'master_graph_url': 'original',
        'thumbnail_base64': 'thumbnail',
      }),
      throwsA(isA<PostgrestException>()),
    );
    expect(jsonDecode(requests.single.body)['thumbnail_base64'], 'thumbnail');
    missingColumn = false;
    requests.clear();
    final first = load('held');
    await started.future;
    final second = load('held');
    await Future<void>.delayed(Duration.zero);
    release.complete();
    expect(await Future.wait([first, second]), [null, null]);
    expect(requests, hasLength(1));
    await load('held');
    expect(requests, hasLength(2));

    Future<void> shared() async {
      const images = RepositoryAccountImage();
      expect(
        await Future.wait([
          images.readShared('share-a', thumbnail: true),
          images.readShared('share-b', thumbnail: true),
        ]),
        [null, null],
      );
    }

    requests.clear();
    await shared();
    expect(
      requests.single.url.pathSegments.last,
      'read_my_shared_ledger_thumbnails',
    );
    expect(jsonDecode(requests.single.body)['p_share_ids'], [
      'share-a',
      'share-b',
    ]);
    requests.clear();
    batchInstalled = false;
    await expectLater(
      Future.wait([
        const RepositoryAccountImage().readShared('share-a', thumbnail: true),
        const RepositoryAccountImage().readShared('share-b', thumbnail: true),
      ]),
      throwsA(
        isA<PostgrestException>().having((e) => e.code, 'code', 'PGRST202'),
      ),
    );
    expect(
      requests.single.url.pathSegments.last,
      'read_my_shared_ledger_thumbnails',
    );
  });
}
