import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/local_storage/local_data_store.dart';
import 'package:sembast/sembast_memory.dart';

void main() {
  late Database database;
  late LocalDataStore store;
  var databaseIndex = 0;
  const owner = 'person@example.com';
  const resource = 'accounting_detail';
  setUp(() async {
    database = await databaseFactoryMemory.openDatabase(
      'ledger-day-index-${databaseIndex++}',
    );
    store = LocalDataStore.withDatabase(database);
  });
  tearDown(() => database.close());

  Future<void> put(String id, num value, String date) => store.put(
    owner: owner,
    resource: resource,
    id: id,
    data: {
      'id': id,
      'account_id': 'account',
      'currency': 'TWD',
      'value': value,
      'date': date,
    },
  );

  test(
    'missing day index builds once and later writes keep it current',
    () async {
      await put('older', 5, '2026-11-15T08:00:00');
      await put('first', 10, '2026-11-16T08:00:00');
      await put('second', -3, '2026-11-16T09:00:00');

      var result = await store.ledgerDaySummary(
        owner: owner,
        resource: resource,
        accountId: 'account',
        currency: 'TWD',
        day: DateTime(2026, 11, 16),
      );
      expect(result.total, 7);
      expect(result.rows.map((row) => row['id']), ['second', 'first']);

      await put('third', 4, '2026-11-16T10:00:00');
      await put('first', 20, '2026-11-16T08:00:00');
      await store.delete(owner: owner, resource: resource, id: 'second');
      result = await store.ledgerDaySummary(
        owner: owner,
        resource: resource,
        accountId: 'account',
        currency: 'TWD',
        day: DateTime(2026, 11, 16),
      );
      expect(result.total, 24);
      expect(result.rows.map((row) => row['id']), ['third', 'first']);
    },
  );

  test('moving a detail to another day updates both cached days', () async {
    await put('entry', 8, '2026-11-16T08:00:00');
    for (final day in [16, 17]) {
      await store.ledgerDaySummary(
        owner: owner,
        resource: resource,
        accountId: 'account',
        currency: 'TWD',
        day: DateTime(2026, 11, day),
      );
    }
    await put('entry', 8, '2026-11-17T08:00:00');
    final first = await store.ledgerDaySummary(
      owner: owner,
      resource: resource,
      accountId: 'account',
      currency: 'TWD',
      day: DateTime(2026, 11, 16),
    );
    final second = await store.ledgerDaySummary(
      owner: owner,
      resource: resource,
      accountId: 'account',
      currency: 'TWD',
      day: DateTime(2026, 11, 17),
    );
    expect(first.total, 0);
    expect(first.rows, isEmpty);
    expect(second.total, 8);
    expect(second.rows.single['id'], 'entry');
  });
}
