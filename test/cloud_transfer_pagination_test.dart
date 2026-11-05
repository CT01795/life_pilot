import 'dart:async';
import 'package:life_pilot/game/repository_versioned_game_catalog.dart';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:life_pilot/local_storage/local_data_store.dart';
import 'package:life_pilot/local_storage/repository_cloud_transfer_export.dart';
import 'package:life_pilot/local_storage/service_local_data_transfer.dart';

Future<void> login(SupabaseClient c, String email) => c.auth.setInitialSession(
  jsonEncode({
    'access_token': 'token-$email',
    'token_type': 'bearer',
    'user': {
      'id': email,
      'email': email,
      'app_metadata': {},
      'user_metadata': {},
      'aud': 'authenticated',
      'created_at': '2026-01-01T00:00:00Z',
    },
  }),
);
Map<String, dynamic> record(int i, {String table = 'memory_trace'}) => {
  'table_name': table,
  'record': {
    'id': 'id$i',
    'master_graph_url': 'Zm9v',
    'sub_events': [
      {'name': 'child'},
    ],
    'value': 23.4567,
  },
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SupabaseClient client;
  late Database db;
  late LocalDataStore store;
  late List<http.Request> requests;
  late List<Map<String, dynamic>> rows;
  var cap = 1000, sequence = 0;
  var failSecond = false,
      deleteLost = false,
      deleteMismatch = false,
      switchSecond = false;
  List<dynamic>? deletedPayload;
  String? catalogVersion;
  setUp(() async {
    requests = [];
    rows = [record(1), record(2), record(3)];
    cap = 1000;
    failSecond = false;
    deleteLost = false;
    deleteMismatch = false;
    switchSecond = false;
    deletedPayload = null;
    catalogVersion = '1';
    db = await databaseFactoryMemory.openDatabase('transfer-$sequence');
    sequence++;
    store = LocalDataStore.withDatabase(db);
    client = SupabaseClient(
      'https://example.supabase.co',
      'key',
      httpClient: MockClient((request) async {
        requests.add(request);
        Object? body;
        final path = request.url.path;
        if (path.endsWith('/get_my_cloud_transfer_setup')) {
          if (catalogVersion == null) {
            return http.Response(
              '{"code":"PGRST202","message":"missing"}',
              404,
              request: request,
              headers: {'content-type': 'application/json'},
            );
          }
          final sent = (jsonDecode(request.body) as Map)['p_catalog_version'];
          body = {
            'catalog_version': catalogVersion,
            'game_rows': sent == catalogVersion
                ? null
                : [
                    {
                      'id': 'game-$catalogVersion',
                      'game_type': 'test',
                      'game_name': 'test',
                      'level': 1,
                    },
                  ],
            'dashboard_setting': {
              'account': 'one@example.com',
              'language': 'en',
            },
          };
        } else if (path.endsWith('/get_my_cloud_answer_retention') ||
            path.endsWith('/restore_local_personal_records_with_retention')) {
          return http.Response(
            '{"code":"PGRST202","message":"missing"}',
            404,
            request: request,
            headers: {'content-type': 'application/json'},
          );
        } else if (path.endsWith('/export_my_cloud_data_for_local')) {
          final offset = int.parse(
            request.url.queryParameters['offset'] ?? '0',
          );
          if (offset > 0 && failSecond) throw TimeoutException('read failed');
          if (offset > 0 && switchSecond) {
            await login(client, 'two@example.com');
          }
          body = rows.skip(offset).take(cap).toList();
        } else if (path.endsWith(
          '/delete_cloud_records_and_revoke_shares_after_local_copy',
        )) {
          deletedPayload = jsonDecode(request.body)['p_records'] as List;
          if (deleteLost) throw TimeoutException('response lost after commit');
          body = deletedPayload!.length - (deleteMismatch ? 1 : 0);
        } else {
          throw StateError('Unexpected request: $path');
        }
        return http.Response(
          jsonEncode(body),
          200,
          request: request,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    await login(client, 'one@example.com');
  });
  tearDown(() async {
    await client.dispose();
    await db.close();
  });
  ServiceLocalDataTransfer service() =>
      ServiceLocalDataTransfer(client: client, store: store);
  Future<List<Map<String, dynamic>>> local([
    String owner = 'one@example.com',
  ]) => store.list(owner: owner, resource: 'memory_trace');
  test(
    'missing retention RPCs never use the legacy restore or erase local data',
    () async {
      await store.put(
        owner: 'one@example.com',
        resource: 'memory_trace',
        id: 'kept',
        data: {'id': 'kept'},
      );
      await expectLater(
        service().cloudAnswerRetention(),
        throwsA(isA<PostgrestException>()),
      );
      expect(
        (await service().uploadLocalToCloud('one@example.com')).succeeded,
        isFalse,
      );
      expect((await local()).single['id'], 'kept');
      expect(requests.map((r) => r.url.pathSegments.last), [
        'get_my_cloud_answer_retention',
        'restore_local_personal_records_with_retention',
      ]);
    },
  );
  int deleteCalls() => requests
      .where(
        (r) => r.url.path.endsWith(
          'delete_cloud_records_and_revoke_shares_after_local_copy',
        ),
      )
      .length;
  test(
    'full export supports project caps lower than requested page size',
    () async {
      cap = 2;
      final pages = await RepositoryCloudTransferExport(
        client: client,
      ).pages('one@example.com').toList();
      expect(pages.map((p) => p.length), [2, 1]);
      expect(requests, hasLength(3));
      expect(requests.map((r) => r.url.queryParameters['offset']), [
        '0',
        '2',
        '3',
      ]);
      expect(pages.first.first['record']['master_graph_url'], 'Zm9v');
      expect(requests.every((r) => !r.url.path.contains('excel')), isTrue);
    },
  );
  test(
    '1000+ records retain every image/subevent/game record before deletion',
    () async {
      rows = [
        for (var i = 0; i < 1001; i++) record(i),
        {
          'table_name': 'game_social_scenarios',
          'record': {
            'id': 'social',
            'choices': [
              {'text': 'choice'},
            ],
          },
        },
        {
          'table_name': 'game_user',
          'record': {'id': 'score', 'score': 23.4},
        },
      ];
      final result = await service().moveCloudToLocal('one@example.com');
      expect(result.succeeded, isTrue);
      expect(result.moved, 1003);
      expect(deletedPayload, hasLength(1003));
      expect(await local(), hasLength(1001));
      final first = (await local()).first;
      expect(first['master_graph_url'], 'Zm9v');
      expect(first['sub_events'], [
        {'name': 'child'},
      ]);
      expect(
        (await store.list(
          owner: 'one@example.com',
          resource: 'game_social_scenarios',
        )).single['choices'],
        [
          {'text': 'choice'},
        ],
      );
      expect(
        (await store.list(
          owner: 'one@example.com',
          resource: 'game_user',
        )).single['score'],
        23.4,
      );
      expect(deleteCalls(), 1);
      expect(
        requests.where(
          (r) => r.url.path.endsWith('/get_my_cloud_transfer_setup'),
        ),
        hasLength(1),
      );
      expect(
        requests.any(
          (r) =>
              r.url.path.endsWith('/game_list') ||
              r.url.path.endsWith('/dashboard_setting'),
        ),
        isFalse,
      );
    },
  );
  test(
    'missing transfer setup never reads old tables or deletes cloud data',
    () async {
      catalogVersion = null;
      final result = await service().moveCloudToLocal('one@example.com');
      expect(result.succeeded, isFalse);
      expect(deleteCalls(), 0);
      expect(await local(), isEmpty);
      expect(
        requests.any(
          (r) =>
              r.url.path.endsWith('/game_list') ||
              r.url.path.endsWith('/dashboard_setting'),
        ),
        isFalse,
      );
    },
  );
  test(
    'transfer sends cached revision and replaces the catalog only when it changes',
    () async {
      rows = [];
      catalogVersion = '1';
      final catalog = RepositoryVersionedGameCatalog(store);
      final sent = <Object?>[];
      for (final revision in ['1', '1', '2']) {
        catalogVersion = revision;
        requests.clear();
        expect(
          (await service().moveCloudToLocal('one@example.com')).succeeded,
          isTrue,
        );
        final setup = requests.singleWhere(
          (r) => r.url.path.endsWith('/get_my_cloud_transfer_setup'),
        );
        sent.add((jsonDecode(setup.body) as Map)['p_catalog_version']);
        expect(
          requests.any(
            (r) =>
                r.url.path.endsWith('/game_list') ||
                r.url.path.endsWith('/dashboard_setting'),
          ),
          isFalse,
        );
        final snapshot = (await catalog.read('one@example.com'))!;
        expect(snapshot.version, revision);
        expect(snapshot.rows.single['id'], 'game-$revision');
      }
      expect(sent, [null, '1', '1']);
    },
  );
  test(
    'later export failure rolls back staged copies and never deletes cloud data',
    () async {
      cap = 2;
      failSecond = true;
      final result = await service().moveCloudToLocal('one@example.com');
      expect(result.succeeded, isFalse);
      expect(await local(), isEmpty);
      expect(deleteCalls(), 0);
    },
  );
  test(
    'received calendar events never enter the move or delete list',
    () async {
      rows = [
        for (final (id, owner) in [
          (1, 'one@example.com'),
          (2, 'other@example.com'),
        ])
          {
            'table_name': 'calendar_events',
            'record': {'id': 'id$id', 'account': owner},
          },
      ];
      final result = await service().moveCloudToLocal('one@example.com');
      expect(result.moved, 1);
      expect(deletedPayload, [
        {'table_name': 'calendar_events', 'id': 'id1'},
      ]);
      expect(
        await store.contains(
          owner: 'one@example.com',
          resource: 'calendar_events',
          id: 'id2',
        ),
        isFalse,
      );
    },
  );
  test(
    'filtered local reads isolate owner, resource and matching rows',
    () async {
      for (final (owner, resource, id, game) in [
        ('one@example.com', 'game_user', '1', 'wanted'),
        ('one@example.com', 'game_user', '2', 'other'),
        ('two@example.com', 'game_user', '3', 'wanted'),
        ('one@example.com', 'other_resource', '4', 'wanted'),
      ]) {
        await store.put(
          owner: owner,
          resource: resource,
          id: id,
          data: {'id': id, 'game_id': game},
        );
      }
      final result = await store.readOnlyMatchingRows(
        owner: 'one@example.com',
        resource: 'game_user',
        matches: (row) => row['game_id'] == 'wanted',
      );
      expect(result.map((row) => row['id']), ['1']);
      expect(
        await store.readOnlyRows(
          owner: 'one@example.com',
          resource: 'game_user',
        ),
        hasLength(2),
      );
    },
  );
  test(
    'unsupported later resource cannot leave a partial local transfer',
    () async {
      cap = 2;
      rows = [record(1), record(2), record(3, table: 'unsupported')];
      final result = await service().moveCloudToLocal('one@example.com');
      expect(result.succeeded, isFalse);
      expect(await local(), isEmpty);
      expect(deleteCalls(), 0);
    },
  );
  test('bad later ID rolls back earlier pages', () async {
    cap = 2;
    rows = [
      record(1),
      record(2),
      {
        'table_name': 'memory_trace',
        'record': {'description': 'no id'},
      },
    ];
    final result = await service().moveCloudToLocal('one@example.com');
    expect(result.succeeded, isFalse);
    expect(await local(), isEmpty);
    expect(deleteCalls(), 0);
  });
  test(
    'preexisting local conflict is preserved while new staged records roll back',
    () async {
      cap = 2;
      await store.put(
        owner: 'one@example.com',
        resource: 'memory_trace',
        id: 'id3',
        data: {'id': 'id3', 'name': 'keep'},
      );
      final result = await service().moveCloudToLocal('one@example.com');
      expect(result.succeeded, isFalse);
      expect((await local()).single['name'], 'keep');
      expect(deleteCalls(), 0);
    },
  );
  for (final lost in [false, true]) {
    test(
      'uncertain cloud cleanup keeps all local copies (lost=$lost)',
      () async {
        deleteLost = lost;
        deleteMismatch = !lost;
        final result = await service().moveCloudToLocal('one@example.com');
        expect(result.succeeded, isFalse);
        expect(
          result.failureReason,
          'cloud_delete_unconfirmed_local_copy_kept',
        );
        expect(await local(), hasLength(3));
        expect(deleteCalls(), 1);
        expect(
          await store.list(
            owner: 'one@example.com',
            resource: 'dashboard_setting',
          ),
          hasLength(1),
        );
      },
    );
  }
  test(
    'account switch stops paging and does not touch the other local account',
    () async {
      cap = 2;
      switchSecond = true;
      await store.put(
        owner: 'two@example.com',
        resource: 'memory_trace',
        id: 'keep',
        data: {'id': 'keep'},
      );
      final result = await service().moveCloudToLocal('one@example.com');
      expect(result.succeeded, isFalse);
      expect(await local(), isEmpty);
      expect(await local('two@example.com'), hasLength(1));
      expect(deleteCalls(), 0);
    },
  );
  test('duplicate export row fails instead of repeated downloads', () async {
    cap = 1;
    rows = [record(1), record(1)];
    final result = await service().moveCloudToLocal('one@example.com');
    expect(result.succeeded, isFalse);
    expect(await local(), isEmpty);
    expect(deleteCalls(), 0);
  });
}
