import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/local_storage/local_data_store.dart';
import 'package:life_pilot/local_storage/repository_local_record_editor.dart';
import 'package:sembast/sembast_memory.dart';

class _Store extends LocalDataStore {
  _Store(super.database) : super.withDatabase();
  bool failRead = false;
  int writes = 0;
  @override
  Future<Map<String, dynamic>?> readOnlyRow({
    required String owner,
    required String resource,
    required String id,
  }) {
    if (failRead) throw StateError('read unavailable');
    return super.readOnlyRow(owner: owner, resource: resource, id: id);
  }

  @override
  Future<List<Map<String, dynamic>>> list({
    required String owner,
    required String resource,
  }) => throw StateError('Editor must not load the complete resource');
  @override
  Future<void> put({
    required String owner,
    required String resource,
    required String id,
    required Map<String, Object?> data,
    LocalSyncState syncState = LocalSyncState.localOnly,
    String? originalCloudId,
  }) {
    writes++;
    return super.put(
      owner: owner,
      resource: resource,
      id: id,
      data: data,
      syncState: syncState,
      originalCloudId: originalCloudId,
    );
  }
}

void main() {
  late Database db;
  late _Store store;
  late RepositoryLocalRecordEditor repository;
  var sequence = 0;
  const owner = 'one@example.com', resource = 'accounting_detail';
  Future<void> seed({String user = owner, String table = resource}) =>
      store.put(
        owner: user,
        resource: table,
        id: 'one',
        data: {
          'id': 'one',
          'account_id': 'cash',
          'event_id': 'trip',
          'date': '2026-10-21',
          'value': 23.4567,
          'currency': 'TWD',
          'description': 'Original',
          'primary_category': 'food',
          'group': 'Lunch',
        },
      );
  Future<Map<String, dynamic>?> read({
    String user = owner,
    String table = resource,
  }) => store.readOnlyRow(owner: user, resource: table, id: 'one');
  Future<void> update(
    Map<String, Object?> fields, {
    String table = resource,
    String message = 'not_found',
  }) => repository.updateFields(
    owner: owner,
    resource: table,
    id: 'one',
    fields: fields,
    notFoundMessage: message,
  );
  setUp(() async {
    db = await databaseFactoryMemory.openDatabase('editor-${sequence++}');
    store = _Store(db);
    repository = RepositoryLocalRecordEditor(store: store);
  });
  tearDown(() => db.close());

  test(
    'changes selected fields while retaining account/event links and decimals',
    () async {
      await seed();
      await update({
        'description': 'Edited',
        'date': '2026-10-22',
        'group': 'Dinner',
      });
      final row = (await read())!;
      expect(row['description'], 'Edited');
      expect(row['group'], 'Dinner');
      expect(row['account_id'], 'cash');
      expect(row['event_id'], 'trip');
      expect(row['value'], 23.4567);
      expect(row['currency'], 'TWD');
      expect(row['primary_category'], 'food');
    },
  );
  for (final entry in {
    'accounting_account': 'accounting_account_not_found',
    'point_record_account': 'point_account_not_found',
    'accounting_detail': 'accounting_detail_not_found',
    'point_record_detail': 'point_detail_not_found',
  }.entries) {
    test(
      '${entry.key} missing keeps the original error and never creates a row',
      () async {
        await expectLater(
          update({'value': 1}, table: entry.key, message: entry.value),
          throwsA(
            isA<StateError>().having((e) => e.message, 'message', entry.value),
          ),
        );
        expect(await read(table: entry.key), isNull);
        expect(store.writes, 0);
      },
    );
  }
  test('image update preserves other account fields', () async {
    await seed(table: 'point_record_account');
    await update({
      'master_graph_url': 'new-image',
    }, table: 'point_record_account');
    final row = (await read(table: 'point_record_account'))!;
    expect(row['master_graph_url'], 'new-image');
    expect(row['event_id'], 'trip');
  });
  test('same ID remains isolated by owner and resource', () async {
    await seed();
    await seed(user: 'two@example.com');
    await seed(table: 'point_record_detail');
    await update({'description': 'Edited'});
    expect((await read(user: 'two@example.com'))?['description'], 'Original');
    expect(
      (await read(table: 'point_record_detail'))?['description'],
      'Original',
    );
  });
  test(
    'write denial preserves stored data and propagates the failure',
    () async {
      await seed();
      store.setCreateAllowed(owner, false);
      await expectLater(update({'value': 999}), throwsStateError);
      expect((await read())?['value'], 23.4567);
    },
  );
  test(
    'storage read failure is not interpreted as a missing record or a write',
    () async {
      await seed();
      final writes = store.writes;
      store.failRead = true;
      await expectLater(
        update({'value': 999}),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            'read unavailable',
          ),
        ),
      );
      expect(store.writes, writes);
      store.failRead = false;
      expect((await read())?['value'], 23.4567);
    },
  );
  test(
    'updates invalidate list cache without mutating the old snapshot',
    () async {
      await seed();
      final old = await store.readOnlyRows(owner: owner, resource: resource);
      await update({'value': -12.3456});
      final fresh = await store.readOnlyRows(owner: owner, resource: resource);
      expect(old.single['value'], 23.4567);
      expect(fresh.single['value'], -12.3456);
      expect(identical(old, fresh), false);
    },
  );
}
