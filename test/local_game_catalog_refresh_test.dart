import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:life_pilot/game/repository_versioned_game_catalog.dart';
import 'package:life_pilot/game/service_game.dart';
import 'package:life_pilot/local_storage/local_data_store.dart';
import 'package:life_pilot/utils/supabase.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'force refresh persists the versioned catalog for an offline reopen',
    () async {
      const owner = 'game@example.com';
      Map<String, dynamic> game(int level) => {
        'id': 'game-$level',
        'game_type': 'test',
        'game_name': 'game',
        'level': level,
      };
      final versionsSent = <Object?>[];
      final client = SupabaseClient(
        'https://example.supabase.co',
        'test-key',
        httpClient: MockClient((request) async {
          expect(request.url.path, endsWith('/get_my_cloud_transfer_setup'));
          final version =
              (jsonDecode(request.body) as Map)['p_catalog_version'];
          versionsSent.add(version);
          return http.Response(
            jsonEncode({
              'catalog_version': '2',
              'game_rows': version == '2' ? null : [game(1), game(2)],
            }),
            200,
            headers: {'content-type': 'application/json'},
            request: request,
          );
        }),
      );
      supabase = client;
      addTearDown(client.dispose);
      await client.auth.setInitialSession(
        jsonEncode({
          'access_token': 'token',
          'token_type': 'bearer',
          'user': {'id': 'game', 'aud': 'authenticated', 'email': owner},
        }),
      );

      final db = await databaseFactoryMemory.openDatabase(
        'game-catalog-refresh',
      );
      addTearDown(db.close);
      final store = LocalDataStore.withDatabase(db);
      await store.setPreferredLocation(owner, DataStorageLocation.local);
      final repo = RepositoryVersionedGameCatalog(store);
      await repo.write(owner, (version: '1', rows: [game(1)]));
      final service = ServiceGame(catalogStore: store);
      expect((await service.fetchGames()).map((item) => item.level), [1]);
      expect(versionsSent, isEmpty);

      expect(
        (await service.fetchGames(force: true)).map((item) => item.level),
        [1, 2],
      );
      expect((await repo.read(owner))?.version, '2');
      expect(
        (await ServiceGame(
          catalogStore: store,
        ).fetchGames()).map((item) => item.level),
        [1, 2],
      );
      expect(versionsSent, ['1']);

      await service.fetchGames(force: true);
      expect(versionsSent, ['1', '2']);
    },
  );
}
