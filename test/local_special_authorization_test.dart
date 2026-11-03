import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/local_storage/local_data_store.dart';
import 'package:sembast/sembast_memory.dart';

void main() {
  test(
    'local writes are unlimited while authorization remains active',
    () async {
      final db = await databaseFactoryMemory.openDatabase('local-special');
      addTearDown(db.close);
      final store = LocalDataStore.withDatabase(db);
      const owner = 'user@example.com';
      var active = true;
      store.setWriteCheck(owner, () => active);

      Future<void> put(String resource, String id) =>
          store.put(owner: owner, resource: resource, id: id, data: {});

      for (final resource in [
        'calendar_events',
        'accounting_detail',
        'point_record_detail',
        'memory_trace',
        'game_grammar',
        'game_translation',
      ]) {
        await put(resource, 'first');
        await put(resource, 'second');
        expect(await store.count(owner: owner, resource: resource), 2);
      }
      active = false;
      await expectLater(put('calendar_events', 'third'), throwsStateError);
      await expectLater(put('calendar_events', 'first'), throwsStateError);
    },
  );
}
