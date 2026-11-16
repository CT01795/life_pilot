import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/local_storage/local_data_store.dart';
import 'package:sembast/sembast_memory.dart';

void main() {
  const owner = 'owner@example.com';

  test(
    'ledger scope index survives restart and follows type changes',
    () async {
      final database = await databaseFactoryMemory.openDatabase('ledger-scope');
      addTearDown(database.close);
      final store = LocalDataStore.withDatabase(database);
      Future<void> put(String id, String type) => store.put(
        owner: owner,
        resource: 'accounting_detail',
        id: id,
        data: {'id': id, 'account_id': 'a', 'type': type, 'value': 1},
      );

      await put('one', 'balance');
      expect(
        (await store.ledgerScopeRows(
          owner: owner,
          resource: 'accounting_detail',
          accountId: 'a',
          type: 'balance',
        )).map((row) => row['id']),
        ['one'],
      );

      final restarted = LocalDataStore.withDatabase(database);
      await restarted.put(
        owner: owner,
        resource: 'accounting_detail',
        id: 'one',
        data: {'id': 'one', 'account_id': 'a', 'type': 'other', 'value': 1},
      );
      expect(
        await restarted.ledgerScopeRows(
          owner: owner,
          resource: 'accounting_detail',
          accountId: 'a',
          type: 'balance',
        ),
        isEmpty,
      );
      expect(
        (await restarted.ledgerScopeRows(
          owner: owner,
          resource: 'accounting_detail',
          accountId: 'a',
          type: 'other',
        )).single['id'],
        'one',
      );
    },
  );

  test('calendar range index stays current after writes and deletes', () async {
    final database = await databaseFactoryMemory.openDatabase('calendar-range');
    addTearDown(database.close);
    final store = LocalDataStore.withDatabase(database);
    final start = DateTime(2026, 11, 16);
    final end = start.add(const Duration(days: 7));
    Future<void> put(String id, DateTime date, {bool completed = false}) =>
        store.put(
          owner: owner,
          resource: 'calendar_events',
          id: id,
          data: {
            'id': id,
            'start_date': date.toIso8601String(),
            'end_date': date.add(const Duration(hours: 1)).toIso8601String(),
            'is_completed': completed,
          },
        );

    await put('inside', start.add(const Duration(hours: 2)));
    await put('outside', start.subtract(const Duration(days: 1)));
    expect(
      (await store.calendarRowsInRange(
        owner: owner,
        resource: 'calendar_events',
        start: start,
        end: end,
      )).map((row) => row['id']),
      ['inside'],
    );

    await put('outside', start.add(const Duration(days: 1)));
    await store.delete(owner: owner, resource: 'calendar_events', id: 'inside');
    expect(
      (await store.calendarRowsInRange(
        owner: owner,
        resource: 'calendar_events',
        start: start,
        end: end,
      )).map((row) => row['id']),
      ['outside'],
    );
  });

  test('event history index survives restart and follows mutations', () async {
    final database = await databaseFactoryMemory.openDatabase('event-history');
    addTearDown(database.close);
    final store = LocalDataStore.withDatabase(database);
    final boundary = DateTime.utc(2026, 11, 16);

    Future<void> put(String id, Object? date) => store.put(
      owner: owner,
      resource: 'memory_trace',
      id: id,
      data: {'id': id, 'start_date': date, 'name': id},
    );

    await put('old', '2026-11-01T00:00:00Z');
    await put('latest', '2026-11-15T23:00:00Z');
    await put('equal', boundary.toIso8601String());
    await put('invalid', 'not-a-date');
    expect(
      (await store.eventRowBefore(
        owner: owner,
        resource: 'memory_trace',
        before: boundary,
      ))?['id'],
      'latest',
    );

    final restarted = LocalDataStore.withDatabase(database);
    await put('latest', '2026-11-20T00:00:00Z');
    expect(
      (await restarted.eventRowBefore(
        owner: owner,
        resource: 'memory_trace',
        before: boundary,
      ))?['id'],
      'old',
    );
    await restarted.delete(owner: owner, resource: 'memory_trace', id: 'old');
    expect(
      await restarted.eventRowBefore(
        owner: owner,
        resource: 'memory_trace',
        before: boundary,
      ),
      isNull,
    );
  });

  test(
    'event range index keeps undated rows and excludes other dates',
    () async {
      final database = await databaseFactoryMemory.openDatabase('event-range');
      addTearDown(database.close);
      final store = LocalDataStore.withDatabase(database);
      Future<void> put(String id, Object? date) => store.put(
        owner: owner,
        resource: 'memory_trace',
        id: id,
        data: {'id': id, 'start_date': date, 'name': id},
      );
      await put('before', '2026-10-31T23:59:59');
      await put('inside', '2026-11-15T20:00:00');
      await put('after', '2026-12-01T00:00:00');
      await put('missing', null);
      await put('invalid', 'invalid');

      Future<List<String>> ids() async => (await store.eventRowsInRange(
        owner: owner,
        resource: 'memory_trace',
        start: DateTime(2026, 11),
        end: DateTime(2026, 11, 30),
      )).map((row) => row['id'] as String).toList();

      expect(await ids(), containsAll(['inside', 'missing', 'invalid']));
      expect(await ids(), isNot(contains('before')));
      expect(await ids(), isNot(contains('after')));
      await put('inside', '2027-01-01');
      expect(await ids(), isNot(contains('inside')));
    },
  );

  test('first matching row avoids loading unrelated local records', () async {
    final database = await databaseFactoryMemory.openDatabase('first-match');
    addTearDown(database.close);
    final store = LocalDataStore.withDatabase(database);
    await store.put(
      owner: owner,
      resource: 'accounting_account',
      id: 'one',
      data: {'id': 'one', 'name': 'First'},
    );
    await store.put(
      owner: 'other@example.com',
      resource: 'accounting_account',
      id: 'other',
      data: {'id': 'other', 'name': 'Target'},
    );
    await store.put(
      owner: owner,
      resource: 'accounting_account',
      id: 'two',
      data: {'id': 'two', 'name': 'Target'},
    );

    final result = await store.readOnlyFirstMatchingRow(
      owner: owner,
      resource: 'accounting_account',
      matches: (row) => row['name'] == 'Target',
    );
    expect(result?['id'], 'two');
    expect(() => result!['name'] = 'changed', throwsUnsupportedError);
  });

  test('default account pointer repairs itself after deletion', () async {
    final database = await databaseFactoryMemory.openDatabase(
      'default-account',
    );
    addTearDown(database.close);
    final store = LocalDataStore.withDatabase(database);
    Future<void> put(String id, bool valid) => store.put(
      owner: owner,
      resource: 'point_record_account',
      id: id,
      data: {'id': id, 'is_valid': valid, 'points': 0},
    );

    await put('invalid', false);
    await put('first', true);
    expect(
      (await store.defaultAccount(
        owner: owner,
        resource: 'point_record_account',
      ))?['id'],
      'first',
    );
    await put('second', true);
    await store.delete(
      owner: owner,
      resource: 'point_record_account',
      id: 'first',
    );
    expect(
      (await LocalDataStore.withDatabase(
        database,
      ).defaultAccount(owner: owner, resource: 'point_record_account'))?['id'],
      'second',
    );
  });
}
