import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/local_storage/local_data_store.dart';
import 'package:life_pilot/local_storage/repository_local_account_summary.dart';
import 'package:life_pilot/utils/model_local_account_list.dart';
import 'package:sembast/sembast_memory.dart';

class _Store extends LocalDataStore {
  _Store(super.database) : super.withDatabase();
  final keyReads = <String>[];
  final listReads = <String>[];
  @override
  Future<List<Map<String, dynamic>>> list({
    required String owner,
    required String resource,
  }) => throw StateError('Do not clone all records');
  @override
  Future<Map<String, dynamic>?> readOnlyRow({
    required String owner,
    required String resource,
    required String id,
  }) {
    keyReads.add('$owner:$resource:$id');
    return super.readOnlyRow(owner: owner, resource: resource, id: id);
  }

  @override
  Future<List<Map<String, dynamic>>> readOnlyRows({
    required String owner,
    required String resource,
  }) {
    if (resource.endsWith('_account')) {
      throw StateError('Do not read the account list');
    }
    listReads.add('$owner:$resource');
    return super.readOnlyRows(owner: owner, resource: resource);
  }
}

void main() {
  var sequence = 0;
  for (final points in [false, true]) {
    group(points ? 'points' : 'accounting', () {
      late Database database;
      late _Store store;
      late RepositoryLocalAccountSummary repository;
      const owner = 'one@example.com';
      final accounts = points ? 'point_record_account' : 'accounting_account';
      final details = points ? 'point_record_detail' : 'accounting_detail';
      Future<void> putAccount({bool valid = true, String user = owner}) =>
          store.put(
            owner: user,
            resource: accounts,
            id: 'selected',
            data: {
              'id': 'selected',
              'account': 'Selected',
              'is_valid': valid,
              'category': 'personal',
              'main_currency': 'TWD',
              'balance': 999,
              'points': 999,
            },
          );
      Future<void> putDetail(
        String id,
        Object value, {
        String account = 'selected',
        String currency = 'TWD',
      }) => store.put(
        owner: owner,
        resource: details,
        id: id,
        data: {
          'id': id,
          'account_id': account,
          'value': value,
          'currency': currency,
          'date': '2020-01-01',
          'primary_category': 'reserved',
          'type': 'other',
        },
      );
      Future<({Map<String, dynamic> row, num total})?> read({
        String id = 'selected',
      }) => repository.read(owner: owner, accountId: id, points: points);
      setUp(() async {
        database = await databaseFactoryMemory.openDatabase(
          'account-summary-${sequence++}',
        );
        store = _Store(database);
        repository = RepositoryLocalAccountSummary(store: store);
      });
      tearDown(() => database.close());

      test('exact row read and total match full account-list rules', () async {
        await putAccount();
        await putDetail('one', '12.3456');
        await putDetail('two', -2);
        await putDetail('currency', 100, currency: 'USD');
        await putDetail('other', 500, account: 'other');
        final result = (await read())!;
        expect(result.row['id'], 'selected');
        expect(store.keyReads, ['$owner:$accounts:selected']);
        expect(store.listReads, ['$owner:$details']);
        final rows = await store.readOnlyRows(owner: owner, resource: details);
        final reference = points
            ? ModelLocalAccountList.points([result.row], rows)
            : ModelLocalAccountList.accounting([result.row], rows);
        expect(result.total, reference.totalFor(result.row));
        expect(result.total, isNot(999));
      });

      test('missing account skips the detail resource', () async {
        expect(await read(), null);
        expect(store.listReads, isEmpty);
      });
      test('invalid account skips the detail resource', () async {
        await putAccount(valid: false);
        expect(await read(), null);
        expect(store.listReads, isEmpty);
      });
      test(
        'another owner with the same account ID cannot be returned',
        () async {
          await putAccount(user: 'other@example.com');
          expect(await read(), null);
          expect(store.listReads, isEmpty);
        },
      );
      test('empty account IDs perform no resource reads', () async {
        expect(await read(id: ''), null);
        expect(store.keyReads, isEmpty);
        expect(store.listReads, isEmpty);
      });
      test(
        'detail edits recompute totals without retaining the previous result',
        () async {
          await putAccount();
          await putDetail('one', 10);
          final first = (await read())!;
          await putDetail('one', 20);
          expect((await read())!.total, 20);
          expect(first.total, 10);
        },
      );
      test('detail deletion and recreation invalidate cached totals', () async {
        await putAccount();
        await putDetail('one', 10);
        expect((await read())!.total, 10);
        await store.delete(owner: owner, resource: details, id: 'one');
        expect((await read())!.total, 0);
        await putDetail('one', 25);
        expect((await read())!.total, 25);
      });
      test(
        'clearing and recreating the owner cannot reuse old totals',
        () async {
          await putAccount();
          await putDetail('one', 10);
          expect((await read())!.total, 10);
          await store.deleteAllRecords(owner: owner);
          expect(await read(), isNull);
          await putAccount();
          await putDetail('one', 40);
          expect((await read())!.total, 40);
        },
      );
    });
  }
}
