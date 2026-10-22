import 'dart:async';
import 'dart:collection';
import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:life_pilot/local_storage/local_data_store.dart';
import 'package:life_pilot/record_statistics/model_record_statistics.dart';
import 'package:life_pilot/record_statistics/model_local_record_statistics.dart';
import 'package:life_pilot/record_statistics/service_record_statistics.dart';
import 'package:life_pilot/utils/const.dart';
import 'package:life_pilot/utils/value_parser.dart';

class _CountedDate implements DateTime {
  final DateTime value;
  int reads = 0;
  _CountedDate(this.value);
  @override
  DateTime toLocal() => this;
  @override
  int get year {
    reads++;
    return value.year;
  }

  @override
  int get month {
    reads++;
    return value.month;
  }

  @override
  bool isBefore(DateTime other) {
    reads++;
    return value.isBefore(other);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

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
  Completer<void>? gate;
  int reads = 0;
  _SnapshotStore(super.database) : super.withDatabase();
  @override
  Future<List<Map<String, dynamic>>> readOnlyRows({
    required String owner,
    required String resource,
  }) async {
    reads++;
    await gate?.future;
    return snapshot;
  }
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

  for (final kind in RecordStatisticsKind.values) {
    test(
      '$kind month buckets match legacy filtering across randomized data',
      () {
        final random = Random(43);
        for (var batch = 0; batch < 80; batch++) {
          final source = List<Map<String, dynamic>>.generate(
            150,
            (index) => {
              'id': '$index',
              'account_id': index % 7 == 0 ? 'b' : 'a',
              'currency': index % 4 == 0 ? 'USD' : 'TWD',
              'date': index % 17 == 0
                  ? 'invalid'
                  : DateTime(
                      2025,
                      1 + random.nextInt(36),
                      1 + random.nextInt(28),
                    ).toUtc().toIso8601String(),
              'value': index % 9 == 0 ? '2.3456' : random.nextInt(2000) - 1000,
            },
          );
          for (final currency in <String?>['TWD', null]) {
            final matching = source
                .where(
                  (row) =>
                      row['account_id'] == 'a' &&
                      (kind == RecordStatisticsKind.points ||
                          currency == null ||
                          row['currency'] == currency),
                )
                .toList();
            final model = ModelLocalRecordStatistics(
              source,
              accountId: 'a',
              kind: kind,
              currency: currency,
            );
            expect(
              model.total,
              matching.fold<num>(
                0,
                (sum, row) => sum + parseNumValue(row['value']),
              ),
            );
            expect(
              model.rows(now: now, history: true),
              matching.where(
                (row) =>
                    tryParseDateTimeValue(row['date'], toLocal: true) != null,
              ),
            );
            for (final month in [
              DateTime(2025),
              DateTime(2026, 10),
              DateTime(2027, 12),
            ]) {
              final end = DateTime(month.year, month.month + 1);
              final expected = matching.where((row) {
                final date = tryParseDateTimeValue(row['date'], toLocal: true);
                return date != null &&
                    !date.isBefore(month) &&
                    date.isBefore(end);
              });
              expect(model.rows(now: month), expected);
            }
          }
        }
      },
    );
  }

  test('repeated month lookups never revisit parsed historical dates', () {
    final dates = List.generate(
      2400,
      (index) => _CountedDate(DateTime(2000 + index ~/ 12, index % 12 + 1)),
    );
    final source = List<Map<String, dynamic>>.generate(
      dates.length,
      (index) => {
        'account_id': 'a',
        'currency': 'TWD',
        'value': 1,
        'date': dates[index],
      },
    );
    final model = ModelLocalRecordStatistics(
      source,
      accountId: 'a',
      kind: RecordStatisticsKind.accounting,
      currency: 'TWD',
    );
    final reads = dates.fold<int>(0, (sum, date) => sum + date.reads);
    for (var index = 0; index < 100; index++) {
      expect(model.rows(now: DateTime(2026, 10)), hasLength(1));
      expect(model.rows(now: DateTime(3000)), isEmpty);
    }
    expect(dates.fold<int>(0, (sum, date) => sum + date.reads), reads);
  });

  test('month boundaries use parsed local dates and preserve input order', () {
    final first = DateTime(2026, 10);
    final source = <Map<String, dynamic>>[
      {
        'id': 'end',
        'account_id': 'a',
        'date': DateTime(
          2026,
          11,
        ).subtract(const Duration(microseconds: 1)).toUtc(),
        'value': -2,
      },
      {
        'id': 'before',
        'account_id': 'a',
        'date': first.subtract(const Duration(microseconds: 1)).toUtc(),
        'value': 3,
      },
      {
        'id': 'first',
        'account_id': 'a',
        'date': first.toUtc().toIso8601String(),
        'value': 4,
      },
      {
        'id': 'next',
        'account_id': 'a',
        'date': DateTime(2026, 11).toUtc(),
        'value': 5,
      },
    ];
    final model = ModelLocalRecordStatistics(
      source,
      accountId: 'a',
      kind: RecordStatisticsKind.points,
    );
    expect(model.rows(now: now).map((row) => row['id']), ['end', 'first']);
    expect(identical(model.rows(now: now).first, source.first), true);
  });

  test(
    'mutating returned month and history lists cannot alter bucket contents',
    () {
      final source = List<Map<String, dynamic>>.unmodifiable([
        row('a', 1),
        row('b', 2, date: '2025-12-01'),
      ]);
      final model = ModelLocalRecordStatistics(
        source,
        accountId: 'a',
        kind: RecordStatisticsKind.points,
      );
      model.rows(now: now).add(row('injected', 99));
      model.rows(now: now, history: true).clear();
      expect(model.rows(now: now).map((row) => row['id']), ['a']);
      expect(model.rows(now: now, history: true).map((row) => row['id']), [
        'a',
        'b',
      ]);
      expect(model.total, 3);
      expect(source.length, 2);
    },
  );

  test('empty buckets and empty sources return independent mutable lists', () {
    final model = ModelLocalRecordStatistics(
      [],
      accountId: 'a',
      kind: RecordStatisticsKind.points,
    );
    model.rows(now: now).add(row('new', 1));
    expect(model.rows(now: now), isEmpty);
    expect(model.rows(now: now, history: true), isEmpty);
    expect(model.total, 0);
  });
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
    for (final kind in RecordStatisticsKind.values) {
      test(
        '$kind: cancellation during local IO skips projection work',
        () async {
          final source = _CountedRow(row('a', 12));
          store.snapshot = List.unmodifiable([source]);
          store.gate = Completer<void>();
          var active = true;
          final pending = service.read(
            owner: 'one@example.com',
            storage: DataStorageLocation.local,
            accountId: 'a',
            kind: kind,
            currency: 'TWD',
            now: now,
            shouldContinue: () => active,
          );
          active = false;
          store.gate!.complete();
          expect(await pending, isEmpty);
          expect(source.reads, 0);
          store.gate = null;
          expect(await total(kind: kind), 12);
          expect(source.reads, greaterThan(0));
        },
      );
      test(
        '$kind: cancelled replacement cannot corrupt the previous cache',
        () async {
          final old = _CountedRow(row('a', 10));
          final previous = List<Map<String, dynamic>>.unmodifiable([old]);
          store.snapshot = previous;
          expect(await total(kind: kind), 10);
          final previousReads = old.reads;
          final replacement = _CountedRow(row('a', 20));
          store.snapshot = List.unmodifiable([replacement]);
          store.gate = Completer<void>();
          var active = true;
          final pending = service.read(
            owner: 'one@example.com',
            storage: DataStorageLocation.local,
            accountId: 'a',
            kind: kind,
            currency: 'TWD',
            now: now,
            shouldContinue: () => active,
          );
          active = false;
          store.gate!.complete();
          expect(await pending, isEmpty);
          expect(replacement.reads, 0);
          store.gate = null;
          store.snapshot = previous;
          expect(await total(kind: kind), 10);
          expect(old.reads, previousReads);
          store.snapshot = List.unmodifiable([replacement]);
          expect(await total(kind: kind), 20);
        },
      );
    }
    test('already cancelled local reads perform no database request', () async {
      expect(
        await service.read(
          owner: 'one@example.com',
          storage: DataStorageLocation.local,
          accountId: 'a',
          kind: RecordStatisticsKind.accounting,
          now: now,
          shouldContinue: () => false,
        ),
        isEmpty,
      );
      expect(store.reads, 0);
    });
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
