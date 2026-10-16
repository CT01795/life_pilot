import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/local_storage/local_data_store.dart';
import 'package:sembast/sembast_memory.dart';

void main() {
  late Database database;
  late LocalDataStore store;
  var sequence = 0;
  const owner = 'one@example.com', resource = 'memory_trace';
  Future<void> put(
    String id, {
    String account = owner,
    String table = resource,
  }) => store.put(
    owner: account,
    resource: table,
    id: id,
    data: {'id': id, 'name': id, 'start_date': '2026-10-01'},
  );
  Future<List<Map<String, dynamic>>> read() =>
      store.readOnlyRows(owner: owner, resource: resource);

  setUp(() async {
    database = await databaseFactoryMemory.openDatabase(
      'snapshot-${sequence++}',
    );
    store = LocalDataStore.withDatabase(database);
  });
  tearDown(() => database.close());

  test(
    'reuses the same read-only snapshot without cloning every row',
    () async {
      await put('one');
      final first = await read();
      final second = await read();
      expect(identical(first, second), true);
      expect(() => first.add({}), throwsUnsupportedError);
      expect(() => first.single['name'] = 'changed', throwsUnsupportedError);
      final upper = await store.readOnlyRows(
        owner: owner.toUpperCase(),
        resource: resource,
      );
      expect(identical(first, upper), true);
    },
  );

  test('legacy mutable list does not change cached row fields', () async {
    await put('one');
    final mutable = await store.list(owner: owner, resource: resource);
    mutable.single['name'] = 'changed';
    mutable.clear();
    expect((await read()).single['name'], 'one');
  });

  test(
    'put and delete invalidate snapshots without changing an older snapshot',
    () async {
      await put('one');
      final old = await read();
      await put('two');
      final added = await read();
      expect(identical(old, added), false);
      expect(old.length, 1);
      expect(added.length, 2);
      await store.delete(owner: owner, resource: resource, id: 'one');
      expect((await read()).single['id'], 'two');
      expect(added.length, 2);
    },
  );

  test(
    'updates invalidate cached data and preserve account/resource boundaries',
    () async {
      await put('one');
      await put('other', account: 'two@example.com');
      await put('calendar', table: 'calendar_events');
      final first = await read();
      await store.put(
        owner: owner,
        resource: resource,
        id: 'one',
        data: {'id': 'one', 'name': 'updated'},
      );
      expect((await read()).single['name'], 'updated');
      expect(first.single['name'], 'one');
      expect(
        (await store.readOnlyRows(
          owner: 'two@example.com',
          resource: resource,
        )).single['id'],
        'other',
      );
      expect(
        (await store.readOnlyRows(
          owner: owner,
          resource: 'calendar_events',
        )).single['id'],
        'calendar',
      );
    },
  );

  test(
    'bulk deletion and clearing owner records invalidate cached snapshots',
    () async {
      await put('one');
      await put('two');
      await read();
      await store.deleteMany(
        owner: owner,
        records: [(resource: resource, id: 'one')],
      );
      expect((await read()).single['id'], 'two');
      await store.deleteAllRecords(owner: owner);
      expect(await read(), isEmpty);
    },
  );

  test('concurrent readers share a snapshot', () async {
    await put('one');
    final results = await Future.wait([read(), read(), read()]);
    expect(identical(results[0], results[1]), true);
    expect(identical(results[1], results[2]), true);
  });
}
