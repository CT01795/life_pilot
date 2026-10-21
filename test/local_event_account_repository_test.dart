import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/local_storage/local_data_store.dart';
import 'package:life_pilot/local_storage/repository_local_event_account.dart';
import 'package:sembast/sembast_memory.dart';

class _Store extends LocalDataStore {
  _Store(super.database) : super.withDatabase();
  final listReads = <String>[];
  final keyReads = <String>[];
  @override
  Future<List<Map<String, dynamic>>> list({
    required String owner,
    required String resource,
  }) => throw StateError('Must not clone whole resource lists');
  @override
  Future<List<Map<String, dynamic>>> readOnlyRows({
    required String owner,
    required String resource,
  }) {
    listReads.add(resource);
    return super.readOnlyRows(owner: owner, resource: resource);
  }

  @override
  Future<Map<String, dynamic>?> readOnlyRow({
    required String owner,
    required String resource,
    required String id,
  }) {
    keyReads.add('$resource:$id');
    return super.readOnlyRow(owner: owner, resource: resource, id: id);
  }
}

void main() {
  var sequence = 0;
  for (final prefix in ['accounting', 'point_record']) {
    group(prefix, () {
      late Database db;
      late _Store store;
      late RepositoryLocalEventAccount repository;
      const owner = 'one@example.com';
      final accounts = '${prefix}_account', details = '${prefix}_detail';
      Future<void> account(
        String id, {
        bool valid = true,
        String user = owner,
      }) => store.put(
        owner: user,
        resource: accounts,
        id: id,
        data: {'id': id, 'is_valid': valid, 'account': id},
      );
      Future<void> detail(
        String id,
        String accountId,
        String date, {
        String user = owner,
        String event = 'event',
      }) => store.put(
        owner: user,
        resource: details,
        id: id,
        data: {
          'id': id,
          'account_id': accountId,
          'event_id': event,
          'date': date,
        },
      );
      Future<Map<String, dynamic>?> find() => repository.find(
        owner: owner,
        eventId: 'event',
        accountResource: accounts,
        detailResource: details,
      );
      setUp(() async {
        db = await databaseFactoryMemory.openDatabase(
          'event-account-${sequence++}',
        );
        store = _Store(db);
        repository = RepositoryLocalEventAccount(store: store);
      });
      tearDown(() => db.close());

      test(
        'direct account wins without loading any detail or account list',
        () async {
          await account('event');
          await account('other');
          await detail('d', 'other', '2026-10-20');
          expect((await find())?['id'], 'event');
          expect(store.listReads, isEmpty);
          expect(store.keyReads, ['$accounts:event']);
        },
      );
      test(
        'fallback uses newest linked detail and only reads that account',
        () async {
          await account('old');
          await account('new');
          await detail('d1', 'old', '2026-10-19');
          await detail('d2', 'new', '2026-10-20');
          await detail('d3', 'old', '2026-10-21', event: 'unrelated');
          expect((await find())?['id'], 'new');
          expect(store.listReads, [details]);
          expect(store.keyReads, ['$accounts:event', '$accounts:new']);
        },
      );
      test(
        'invalid direct account still permits linked account fallback',
        () async {
          await account('event', valid: false);
          await account('linked');
          await detail('d', 'linked', '2026-10-20');
          expect((await find())?['id'], 'linked');
        },
      );
      test(
        'invalid newest linked account does not select an older account',
        () async {
          await account('old');
          await account('new', valid: false);
          await detail('d1', 'old', '2026-10-19');
          await detail('d2', 'new', '2026-10-20');
          expect(await find(), isNull);
        },
      );
      test(
        'missing records return null without an invalid account read',
        () async {
          expect(await find(), isNull);
          expect(store.keyReads, ['$accounts:event']);
        },
      );
      test('another owner cannot supply accounts or linked details', () async {
        await account('event', user: 'two@example.com');
        await detail('d', 'event', '2026-10-20', user: 'two@example.com');
        expect(await find(), isNull);
      });
      test('edits and deletion are visible to subsequent lookups', () async {
        await account('event');
        final first = await find();
        expect(() => first!['is_valid'] = false, throwsUnsupportedError);
        await account('event', valid: false);
        expect(await find(), isNull);
        await account('event');
        await store.delete(owner: owner, resource: accounts, id: 'event');
        expect(await find(), isNull);
        expect(first?['is_valid'], true);
      });
    });
  }
}
