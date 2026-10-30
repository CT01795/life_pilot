import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/local_storage/local_data_store.dart';
import 'package:sembast/sembast_memory.dart';

void main() {
  test(
    'no configured allowance blocks insert, update and every deletion path, not reads or other owners',
    () async {
      final db = await databaseFactoryMemory.openDatabase(
        'configuration-read-only',
      );
      final store = LocalDataStore.withDatabase(db);
      try {
        await store.put(
          owner: 'a',
          resource: 'memory_trace',
          id: 'one',
          data: {'name': 'kept'},
        );
        store.setCreateAllowed('a', false);
        store.setDeleteAllowed('a', false);
        final rejected = throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('LIFE_PILOT_QUOTA_CONFIGURATION_MISSING'),
          ),
        );
        await expectLater(
          store.put(owner: 'a', resource: 'memory_trace', id: 'two', data: {}),
          rejected,
        );
        await expectLater(
          store.put(owner: 'a', resource: 'memory_trace', id: 'one', data: {}),
          rejected,
        );
        await expectLater(
          store.delete(owner: 'a', resource: 'memory_trace', id: 'one'),
          rejected,
        );
        await expectLater(
          store.deleteMany(
            owner: 'a',
            records: [(resource: 'memory_trace', id: 'one')],
          ),
          rejected,
        );
        await expectLater(store.deleteAllRecords(owner: 'a'), rejected);
        expect(
          (await store.readOnlyRow(
            owner: 'a',
            resource: 'memory_trace',
            id: 'one',
          ))!['name'],
          'kept',
        );
        await store.put(
          owner: 'b',
          resource: 'memory_trace',
          id: 'one',
          data: {},
        );
        await store.delete(owner: 'b', resource: 'memory_trace', id: 'one');
        store.clearCreatePermission('a');
        await store.delete(owner: 'a', resource: 'memory_trace', id: 'one');
        expect(
          await store.readOnlyRow(
            owner: 'a',
            resource: 'memory_trace',
            id: 'one',
          ),
          null,
        );
      } finally {
        await db.close();
      }
    },
  );
  test(
    'expired but previously configured local plan can still delete when deletion remains allowed',
    () async {
      final db = await databaseFactoryMemory.openDatabase('configured-expired');
      final store = LocalDataStore.withDatabase(db);
      try {
        await store.put(
          owner: 'a',
          resource: 'memory_trace',
          id: 'one',
          data: {},
        );
        store.setCreateAllowed('a', false);
        store.setDeleteAllowed('a', true);
        await store.delete(owner: 'a', resource: 'memory_trace', id: 'one');
        expect(
          await store.readOnlyRow(
            owner: 'a',
            resource: 'memory_trace',
            id: 'one',
          ),
          null,
        );
      } finally {
        await db.close();
      }
    },
  );
}
