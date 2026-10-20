import 'dart:collection';
import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:life_pilot/local_storage/local_data_store.dart';
import 'package:life_pilot/record_statistics/model_record_statistics.dart';
import 'package:life_pilot/record_statistics/model_local_record_statistics.dart';
import 'package:life_pilot/record_statistics/service_record_statistics.dart';
import 'package:life_pilot/utils/const.dart';

class _CountedRow extends MapBase<String, dynamic> {
  final Map<String, dynamic> data;
  int reads = 0;
  _CountedRow(Map<String, dynamic> data) : data = Map.unmodifiable(data);
  @override
  dynamic operator [](Object? key) {
    reads++;
    return data[key];
  }

  @override
  Iterable<String> get keys => data.keys;
  @override
  void operator []=(String key, dynamic value) =>
      throw UnsupportedError('read-only');
  @override
  void clear() => throw UnsupportedError('read-only');
  @override
  dynamic remove(Object? key) => throw UnsupportedError('read-only');
}

class _SnapshotStore extends LocalDataStore {
  List<Map<String, dynamic>> snapshot = const [];
  _SnapshotStore(super.database) : super.withDatabase();
  @override
  Future<List<Map<String, dynamic>>> readOnlyRows({
    required String owner,
    required String resource,
  }) async => snapshot;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final now = DateTime(2026, 10, 20);
  Map<String, dynamic> row(
    String id,
    num value, {
    String account = 'a',
    String currency = 'TWD',
    String date = '2026-10-20',
  }) => {
    'id': id,
    'account_id': account,
    'currency': currency,
    'date': date,
    'value': value,
  };
  test(
    'model retains total, month, history, account and currency semantics',
    () {
      final model = ModelLocalRecordStatistics(
        [
          row('current', 10),
          row('old', 100, date: '2020-01-01'),
          row('future', 20, date: '2026-11-01'),
          row('invalid', 3, date: 'invalid'),
          row('other', 900, account: 'b'),
          row('usd', 800, currency: 'USD'),
        ],
        accountId: 'a',
        kind: RecordStatisticsKind.accounting,
        currency: 'TWD',
      );
      expect(
        model.total,
        133,
      ); // Invalid dates remain included in the original total semantics.
      expect(model.rows(now: now).map((row) => row['id']), ['current']);
      expect(model.rows(now: now, history: true).map((row) => row['id']), [
        'current',
        'old',
        'future',
      ]);
      expect(model.rows(now: DateTime(2026, 11)).map((row) => row['id']), [
        'future',
      ]);
    },
  );
  test(
    'points ignore currency and output list mutations cannot modify the projection',
    () {
      final model = ModelLocalRecordStatistics(
        [row('a', -2), row('b', 5, currency: 'USD')],
        accountId: 'a',
        kind: RecordStatisticsKind.points,
        currency: 'TWD',
      );
      expect(model.total, 3);
      model.rows(now: now).clear();
      expect(model.rows(now: now), hasLength(2));
    },
  );
  group('service snapshot reuse and invalidation', () {
    late Database db;
    late _SnapshotStore store;
    late ServiceRecordStatistics service;
    setUp(() async {
      db = await databaseFactoryMemory.openDatabase('projection');
      store = _SnapshotStore(db);
      service = ServiceRecordStatistics(localStore: store);
    });
    tearDown(() => db.close());
    Future<num> total({
      String owner = 'one@example.com',
      String account = 'a',
      String? currency = 'TWD',
      RecordStatisticsKind kind = RecordStatisticsKind.accounting,
    }) => service.readTotal(
      owner: owner,
      storage: DataStorageLocation.local,
      accountId: account,
      kind: kind,
      currency: currency,
    );
    Future<List<Map<String, dynamic>>> records() => service.read(
      owner: 'one@example.com',
      storage: DataStorageLocation.local,
      accountId: 'a',
      kind: RecordStatisticsKind.accounting,
      currency: 'TWD',
      now: now,
    );
    test(
      'parallel total and monthly read scan the same immutable snapshot only once',
      () async {
        final source = _CountedRow(row('a', 12.3456));
        store.snapshot = List.unmodifiable([source]);
        final first = await total();
        final reads = source.reads;
        expect(first, 12.3456);
        expect(await records(), hasLength(1));
        await Future.wait([total(), records(), total()]);
        expect(source.reads, reads);
      },
    );
    test(
      'replacing a snapshot recalculates even when ID and list length are unchanged',
      () async {
        store.snapshot = List.unmodifiable([row('a', 10)]);
        expect(await total(), 10);
        store.snapshot = List.unmodifiable([row('a', 20)]);
        expect(await total(), 20);
        store.snapshot = const [];
        expect(await total(), 0);
        expect(await records(), isEmpty);
      },
    );
    test(
      'same list identity never reuses another account, currency, owner or resource scope',
      () async {
        final source = _CountedRow(row('a', 5));
        store.snapshot = List.unmodifiable([
          source,
          row('b', 99, account: 'b'),
          row('usd', 7, currency: 'USD'),
        ]);
        expect(await total(), 5);
        expect(await total(account: 'b'), 99);
        expect(await total(currency: 'USD'), 7);
        expect(await total(kind: RecordStatisticsKind.points), 12);
        final reads = source.reads;
        expect(
          await total(
            owner: 'two@example.com',
            kind: RecordStatisticsKind.points,
          ),
          12,
        );
        expect(source.reads, greaterThan(reads));
      },
    );
  });
  test(
    'actual local writes and deletion replace cached snapshots and refresh totals',
    () async {
      final db = await databaseFactoryMemory.openDatabase('real-projection');
      addTearDown(db.close);
      final store = LocalDataStore.withDatabase(db);
      final service = ServiceRecordStatistics(localStore: store);
      Future<num> total() => service.readTotal(
        owner: 'one@example.com',
        storage: DataStorageLocation.local,
        accountId: 'a',
        kind: RecordStatisticsKind.accounting,
        currency: 'TWD',
      );
      Future<void> put(num value) => store.put(
        owner: 'one@example.com',
        resource: TableNames.accountingDetail,
        id: 'a',
        data: row('a', value),
      );
      await put(10);
      expect(await total(), 10);
      await put(20);
      expect(await total(), 20);
      await store.delete(
        owner: 'one@example.com',
        resource: TableNames.accountingDetail,
        id: 'a',
      );
      expect(await total(), 0);
    },
  );
}
