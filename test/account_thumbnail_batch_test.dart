import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:life_pilot/accounting/repository_account_image.dart';
import 'package:life_pilot/local_storage/local_data_store.dart';
import 'package:life_pilot/utils/supabase.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final code in ['PGRST202', '42501']) {
    test(
      'failed thumbnail upgrade keeps original and retries later ($code)',
      () async {
        final recorder = ui.PictureRecorder();
        ui.Canvas(
          recorder,
        ).drawColor(const ui.Color(0xff2196f3), ui.BlendMode.src);
        final picture = recorder.endRecording();
        final image = await picture.toImage(640, 400);
        late Uint8List bytes;
        try {
          final png = (await image.toByteData(format: ui.ImageByteFormat.png))!;
          bytes = png.buffer.asUint8List();
        } finally {
          image.dispose();
          picture.dispose();
        }
        final original = base64Encode(bytes);
        final upgrades = <Map<String, dynamic>>[];
        var completed = Completer<void>();
        final release = Completer<void>();
        final client = SupabaseClient(
          'https://example.supabase.co',
          'key',
          httpClient: MockClient((request) async {
            if (request.url.pathSegments.last ==
                'upgrade_my_ledger_thumbnail') {
              upgrades.add(
                Map<String, dynamic>.from(jsonDecode(request.body) as Map),
              );
              await release.future;
              completed.complete();
              return http.Response(
                jsonEncode({'code': code, 'message': 'upgrade failed'}),
                code == 'PGRST202' ? 404 : 403,
                request: request,
                headers: {'content-type': 'application/json'},
              );
            }
            return http.Response(
              jsonEncode({
                'master_graph_url': original,
                'thumbnail_base64': null,
              }),
              200,
              request: request,
              headers: {'content-type': 'application/json'},
            );
          }),
        );
        addTearDown(client.dispose);
        supabase = client;
        await client.auth.setInitialSession(
          jsonEncode({
            'access_token': 'test-token',
            'token_type': 'bearer',
            'user': {
              'id': 'owner',
              'email': 'owner@example.com',
              'aud': 'authenticated',
              'created_at': '2026-01-01T00:00:00Z',
            },
          }),
        );
        Future<Uint8List?> read() => const RepositoryAccountImage().read(
          table: 'accounting_account',
          accountId: 'account',
          owner: 'owner@example.com',
          storage: DataStorageLocation.cloud,
        );
        // Original reads finish even while the background upgrade is held.
        expect(await read(), orderedEquals(bytes));
        release.complete();
        await completed.future.timeout(const Duration(seconds: 5));
        await Future<void>.delayed(Duration.zero);
        completed = Completer<void>();
        expect(await read(), orderedEquals(bytes));
        await completed.future.timeout(const Duration(seconds: 5));
        await Future<void>.delayed(Duration.zero);
        expect(upgrades, hasLength(2));
        expect(upgrades.first['p_resource'], 'accounting_account');
        expect(upgrades.first['p_account_id'], 'account');
        expect(upgrades.first['p_previous_hash'], isNull);
        final thumbnail = base64Decode(upgrades.first['p_thumbnail'] as String);
        expect(ByteData.sublistView(thumbnail).getUint32(16), 320);
      },
    );
  }
  test(
    'shared original distinguishes no image, malformed result and RPC failure',
    () async {
      var mode = 0;
      final requests = <String>[];
      final client = SupabaseClient(
        'https://example.supabase.co',
        'key',
        httpClient: MockClient((request) async {
          requests.add(request.url.pathSegments.last);
          return http.Response(
            mode == 0
                ? '{"image":null}'
                : mode == 1
                ? '{}'
                : '{"code":"PGRST202","message":"missing"}',
            mode == 2 ? 404 : 200,
            headers: {'content-type': 'application/json'},
            request: request,
          );
        }),
      );
      addTearDown(client.dispose);
      supabase = client;
      await client.auth.setInitialSession(
        jsonEncode({
          'access_token': 'test-token',
          'token_type': 'bearer',
          'user': {
            'id': 'reader',
            'email': 'reader@example.com',
            'aud': 'authenticated',
            'created_at': '2026-01-01T00:00:00Z',
          },
        }),
      );
      const repository = RepositoryAccountImage();
      expect(await repository.readShared('share', thumbnail: false), isNull);
      mode = 1;
      await expectLater(
        repository.readShared('share', thumbnail: false),
        throwsFormatException,
      );
      mode = 2;
      await expectLater(
        repository.readShared('share', thumbnail: false),
        throwsA(isA<PostgrestException>()),
      );
      expect(requests, List.filled(3, 'read_my_shared_ledger_image'));
    },
  );
  test('new account thumbnail keeps 320 pixels and the upload limit', () async {
    final recorder = ui.PictureRecorder();
    ui.Canvas(recorder).drawColor(const ui.Color(0xff2196f3), ui.BlendMode.src);
    final picture = recorder.endRecording();
    final original = await picture.toImage(640, 400);
    try {
      final png = (await original.toByteData(format: ui.ImageByteFormat.png))!;
      final fields = await RepositoryAccountImage.imageFields(
        png.buffer.asUint8List(),
      );
      final thumbnail = fields['thumbnail_base64'] as String;
      expect(thumbnail.length, lessThanOrEqualTo(65536));
      final header = ByteData.sublistView(base64Decode(thumbnail));
      expect(header.getUint32(16), 320);
      expect(header.getUint32(20), 200);
    } finally {
      original.dispose();
      picture.dispose();
    }
  });
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
              ? (rpc == 'read_my_shared_ledger_image' ? '{"image":null}' : '{}')
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
