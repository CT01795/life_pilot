import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:life_pilot/game/service_game.dart';
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

class _Games extends ServiceGame {
  List<Map<String, dynamic>> cached = [];
  @override
  Future<void> cacheGameList(Iterable<Map<String, dynamic>> rows) async {
    cached = rows.toList();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SupabaseClient client;
  late Database db;
  late LocalDataStore store;
  late _Games games;
  late List<http.Request> requests;
  late List<Map<String, dynamic>> rows;
  var cap = 1000, sequence = 0;
  var failSecond = false,
      deleteLost = false,
      deleteMismatch = false,
      switchSecond = false;
  List<dynamic>? deletedPayload;
  setUp(() async {
    requests = [];
    rows = [record(1), record(2), record(3)];
    cap = 1000;
    failSecond = false;
    deleteLost = false;
    deleteMismatch = false;
    switchSecond = false;
    deletedPayload = null;
    games = _Games();
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
        if (path.endsWith('/game_list')) {
          body = [
            {
              'id': 'game',
              'game_type': 'test',
              'game_name': 'test',
              'level': 1,
            },
          ];
        } else if (path.endsWith('/dashboard_setting')) {
          body = [
            {'account': 'one@example.com', 'language': 'en'},
          ];
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
  ServiceLocalDataTransfer service() => ServiceLocalDataTransfer(
    client: client,
    store: store,
    gameService: games,
  );
  Future<List<Map<String, dynamic>>> local([
    String owner = 'one@example.com',
  ]) => store.list(owner: owner, resource: 'memory_trace');
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
      expect(
        requests.first.url.queryParameters['select'],
        'id,game_type,game_name,level',
      );
      expect(deleteCalls(), 1);
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
