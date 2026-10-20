import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/local_storage/local_data_store.dart';
import 'package:sembast/sembast_memory.dart';

class _NoListStore extends LocalDataStore {
  _NoListStore(super.database) : super.withDatabase();

  @override
  Future<List<Map<String, dynamic>>> readOnlyRows({
    required String owner,
    required String resource,
  }) => throw StateError('Single-row reads must not load a list');
}

void main() {
  late Database database;
  late LocalDataStore store;
  var sequence = 0;
  const owner = 'one@example.com';
  const resource = 'accounting_account';
  Future<void> put({
    String account = owner,
    String table = resource,
    String value = 'first',
  }) => store.put(
    owner: account,
    resource: table,
    id: 'one',
    data: {'id': 'one', 'name': value},
  );
  Future<Map<String, dynamic>?> read({
    String account = owner,
    String table = resource,
  }) => store.readOnlyRow(owner: account, resource: table, id: 'one');
  setUp(() async {
    database = await databaseFactoryMemory.openDatabase('single-${sequence++}');
    store = _NoListStore(database);
  });
  tearDown(() => database.close());

  test('missing key returns null rather than an empty record', () async {
    expect(await read(), isNull);
  });
  test('reads one key without opening a resource list', () async {
    await put();
    expect((await read())?['name'], 'first');
  });
  test('same ID remains isolated by owner and resource', () async {
    await put();
    await put(account: 'two@example.com', value: 'other-owner');
    await put(table: 'point_record_account', value: 'points');
    expect((await read())?['name'], 'first');
    expect((await read(account: 'two@example.com'))?['name'], 'other-owner');
    expect((await read(table: 'point_record_account'))?['name'], 'points');
  });
  test('owner casing uses the existing normalized record key', () async {
    await put();
    expect((await read(account: owner.toUpperCase()))?['name'], 'first');
  });
  test('returned top-level fields cannot modify stored data', () async {
    await put();
    final row = (await read())!;
    expect(() => row['name'] = 'changed', throwsUnsupportedError);
    final editable = Map<String, Object?>.from(row)..['name'] = 'edited';
    expect(editable['name'], 'edited');
    expect((await read())?['name'], 'first');
  });
  test('re-reads see edits without changing previous results', () async {
    await put();
    final old = await read();
    await put(value: 'updated');
    expect((await read())?['name'], 'updated');
    expect(old?['name'], 'first');
  });
  test('deleted keys do not survive through a stale snapshot', () async {
    await put();
    await read();
    await store.delete(owner: owner, resource: resource, id: 'one');
    expect(await read(), isNull);
  });
}
