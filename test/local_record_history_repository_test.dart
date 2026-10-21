import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/local_storage/local_data_store.dart';
import 'package:life_pilot/local_storage/repository_local_record_history.dart';
import 'package:sembast/sembast_memory.dart';

class _Store extends LocalDataStore {
  _Store(super.database) : super.withDatabase();
  bool fail = false;
  @override
  Future<List<Map<String, dynamic>>> list({
    required String owner,
    required String resource,
  }) => throw StateError('History must not copy the complete resource');
  @override
  Future<List<Map<String, dynamic>>> readOnlyRows({
    required String owner,
    required String resource,
  }) {
    if (fail) throw StateError('read unavailable');
    return super.readOnlyRows(owner: owner, resource: resource);
  }
}

void main() {
  var sequence = 0;
  for (final resource in ['accounting_detail', 'point_record_detail']) {
    group(resource, () {
      late Database db;
      late _Store store;
      late RepositoryLocalRecordHistory repository;
      final before = DateTime(2026, 10, 1);
      const owner = 'one@example.com';
      final type = resource == 'accounting_detail' ? 'balance' : 'points';
      Future<void> put(
        String id,
        String? date, {
        String user = owner,
        String account = 'a',
        String? rowType,
        String category = 'uncategorized',
      }) => store.put(
        owner: user,
        resource: resource,
        id: id,
        data: {
          'id': id,
          'account_id': account,
          'date': date,
          'type': rowType ?? type,
          'primary_category': category,
        },
      );
      Future<bool> has() => repository.hasRecordsBefore(
        owner: owner,
        resource: resource,
        accountId: 'a',
        type: type,
        before: before,
      );
      Future<DateTime?> latest() => repository.latestRecordDateBefore(
        owner: owner,
        resource: resource,
        accountId: 'a',
        type: type,
        before: before,
      );
      Future<Map<String, dynamic>?> latestDetail() => repository.latestRecord(
        owner: owner,
        resource: resource,
        accountId: 'a',
        type: type,
      );
      setUp(() async {
        db = await databaseFactoryMemory.openDatabase('history-${sequence++}');
        store = _Store(db);
        repository = RepositoryLocalRecordHistory(store: store);
      });
      tearDown(() => db.close());
      test('empty resource returns no history', () async {
        expect(await has(), false);
        expect(await latest(), isNull);
      });
      test(
        'latest defaults include reserved records without a date window',
        () async {
          await put('old', '2026-01-01');
          await put('reserved', '2026-11-01', category: 'reserved');
          await put('other', '2026-12-01', account: 'b');
          expect((await latestDetail())?['id'], 'reserved');
        },
      );
      test(
        'latest defaults return null for nonmatching account or type',
        () async {
          await put('other', '2026-10-01', rowType: 'other');
          expect(await latestDetail(), isNull);
          await put('match', '2026-09-01', rowType: type.toUpperCase());
          expect((await latestDetail())?['id'], 'match');
        },
      );
      test(
        'latest default row is read-only and fresh after mutation',
        () async {
          await put('one', '2026-09-01');
          final previous = await latestDetail();
          expect(() => previous!['date'] = 'changed', throwsUnsupportedError);
          await put('two', '2026-10-01');
          expect((await latestDetail())?['id'], 'two');
          expect(previous?['id'], 'one');
        },
      );
      test('chooses latest eligible date, not source order', () async {
        await put('newer', '2026-09-30');
        await put('old', '2026-01-01');
        expect(await has(), true);
        expect(await latest(), DateTime(2026, 9, 30));
      });
      test('excludes exact boundary, later dates and invalid dates', () async {
        await put('boundary', before.toIso8601String());
        await put('later', '2026-10-02');
        await put('bad', 'not a date');
        await put('missing', null);
        expect(await has(), false);
        expect(await latest(), isNull);
      });
      test(
        'reserved-only history does not keep the history button alive',
        () async {
          await put('reserved', '2020-01-01', category: 'reserved');
          expect(await has(), false);
          expect(await latest(), isNull);
          await put('regular', '2026-09-01');
          expect(await has(), true);
          expect(await latest(), DateTime(2026, 9, 1));
        },
      );
      test(
        'filters owner/account/type while retaining case-insensitive type matching',
        () async {
          await put('owner', '2026-09-30', user: 'two@example.com');
          await put('account', '2026-09-29', account: 'b');
          await put('type', '2026-09-28', rowType: 'other');
          expect(await has(), false);
          await put('match', '2026-09-01', rowType: ' ${type.toUpperCase()} ');
          expect(await latest(), DateTime(2026, 9, 1));
        },
      );
      test('updates and deletes invalidate history snapshots', () async {
        await put('one', '2026-09-01');
        expect(await has(), true);
        await put('one', '2026-11-01');
        expect(await latest(), isNull);
        await put('two', '2026-09-20');
        await store.delete(owner: owner, resource: resource, id: 'two');
        expect(await has(), false);
      });
      test(
        'read failures propagate instead of becoming empty history',
        () async {
          store.fail = true;
          await expectLater(has(), throwsStateError);
          await expectLater(latest(), throwsStateError);
          await expectLater(latestDetail(), throwsStateError);
          store.fail = false;
          await put('one', '2026-09-01');
          expect(await has(), true);
        },
      );
      test(
        'offset timestamps compare as instants and return local dates',
        () async {
          final instant = before.subtract(const Duration(minutes: 1));
          await put('one', instant.toUtc().toIso8601String());
          expect(await has(), true);
          expect(await latest(), instant);
        },
      );
    });
  }
}
