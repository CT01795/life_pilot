import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/auth/controller_auth.dart';
import 'package:life_pilot/local_storage/local_data_store.dart';
import 'package:life_pilot/record_statistics/controller_record_statistics.dart';
import 'package:life_pilot/record_statistics/model_record_statistics.dart';
import 'package:life_pilot/record_statistics/service_record_statistics.dart';
import 'package:life_pilot/utils/const.dart';
import 'package:sembast/sembast_memory.dart';

class StatisticsTestAuth extends ControllerAuth {
  String? owner = 'one@example.com';
  DataStorageLocation storage = DataStorageLocation.cloud;
  @override
  String? get currentAccount => owner;
  @override
  DataStorageLocation get preferredStorage => storage;
  void change({String? account, DataStorageLocation? location}) {
    if (account != null) owner = account;
    if (location != null) storage = location;
    notifyListeners();
  }
}

class StatisticsTestService extends ServiceRecordStatistics {
  final reads = <Completer<List<Map<String, dynamic>>>>[];
  final totals = <Completer<num>>[];
  final scopes = <(String, DataStorageLocation, String, bool)>[];
  @override
  Future<List<Map<String, dynamic>>> read({
    required String owner,
    required DataStorageLocation storage,
    required String accountId,
    required RecordStatisticsKind kind,
    required DateTime now,
    String? currency,
    bool history = false,
  }) {
    scopes.add((owner, storage, accountId, history));
    final result = Completer<List<Map<String, dynamic>>>();
    reads.add(result);
    return result.future;
  }

  @override
  Future<num> readTotal({
    required String owner,
    required DataStorageLocation storage,
    required String accountId,
    required RecordStatisticsKind kind,
    String? currency,
  }) {
    final result = Completer<num>();
    totals.add(result);
    return result.future;
  }

  void finish(int index, {num total = 100}) {
    reads[index].complete([
      {'date': DateTime.now().toIso8601String(), 'value': 5},
    ]);
    if (index < totals.length && !totals[index].isCompleted) {
      totals[index].complete(total);
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final now = DateTime(2026, 10, 19, 15);
  Map<String, dynamic> row(DateTime date, Object value) => {
    'date': date.toIso8601String(),
    'value': value,
  };
  ModelRecordStatistics model(List<Map<String, dynamic>> rows, {num? total}) =>
      ModelRecordStatistics.fromRows(rows, now: now, totalOverride: total);
  test('empty ledger has twelve zero-filled calendar months', () {
    final result = model([]);
    expect([result.total, result.month, result.today], [0, 0, 0]);
    expect(result.months.length, 12);
    expect(result.months.first.month, DateTime(2025, 11));
    expect(result.months.last.month, DateTime(2026, 10));
    expect(result.months.every((m) => m.net == 0 && m.cumulative == 0), true);
  });
  test('month is a calendar month rather than rolling thirty days', () {
    final result = model([
      row(DateTime(2026, 9, 30, 23, 59), 100),
      row(DateTime(2026, 10), -20),
      row(DateTime(2026, 10, 31, 23, 59), 40),
      row(DateTime(2026, 11), 200),
    ]);
    expect(result.month, 20);
    expect(result.total, 320);
    expect(result.months.last.net, 20);
  });
  test('today includes midnight but excludes the following midnight', () {
    final result = model([
      row(DateTime(2026, 10, 18, 23, 59), 100),
      row(DateTime(2026, 10, 19), 10),
      row(DateTime(2026, 10, 19, 23, 59), -3),
      row(DateTime(2026, 10, 20), 20),
    ]);
    expect(result.today, 7);
    expect(result.month, 127);
  });
  test('cumulative chart includes history before the twelve-month window', () {
    final result = model([
      row(DateTime(2020), 1000),
      row(DateTime(2025, 11), -100),
      row(DateTime(2026, 1), 50),
      row(DateTime(2026, 10), -20),
    ]);
    expect(result.months.first.cumulative, 900);
    expect(result.months[1].net, 0);
    expect(result.months[1].cumulative, 900);
    expect(result.months.last.cumulative, 930);
    expect(result.months.last.net, -20);
  });
  test(
    'retained records follow their actual dates in month and today totals',
    () {
      final result = model([
        {...row(DateTime(2020), 100), 'primary_category': 'reserved'},
        row(DateTime(2026, 10, 19), -1),
      ]);
      expect([result.total, result.month, result.today], [99, -1, -1]);
    },
  );
  test('signed numeric strings preserve four decimal places', () {
    final result = model([row(now, '23.1234'), row(now, '-3.0001')]);
    expect(result.month, closeTo(20.1233, 0.0000001));
    expect(result.today, result.month);
  });
  test('missing or malformed dates do not enter statistics', () {
    expect(
      model([
        {'value': 50},
        {'date': 'bad', 'value': 10},
      ]).total,
      0,
    );
  });
  test('authoritative account total does not become month-only total', () {
    final result = model([row(now, 5)], total: 1000);
    expect(result.total, 1000);
    expect(result.month, 5);
  });
  test('December to January month boundaries are correct', () {
    final result = ModelRecordStatistics.fromRows([
      row(DateTime(2025, 12, 31, 23, 59), 9),
      row(DateTime(2026, 1), 4),
      row(DateTime(2026, 2), 8),
    ], now: DateTime(2026, 1, 1));
    expect(result.month, 4);
    expect(result.months.first.month, DateTime(2025, 2));
    expect(result.months.last.cumulative, 13);
  });

  group('controller ownership and lifecycle', () {
    late StatisticsTestAuth auth;
    late StatisticsTestService service;
    late ControllerRecordStatistics controller;
    setUp(() {
      auth = StatisticsTestAuth();
      service = StatisticsTestService();
      controller = ControllerRecordStatistics(
        auth: auth,
        accountId: 'a',
        kind: RecordStatisticsKind.accounting,
        currency: 'TWD',
        service: service,
      );
    });
    tearDown(() {
      if (!controller.notifierDisposed) controller.dispose();
      for (final read in service.reads) {
        if (!read.isCompleted) read.complete([]);
      }
      for (final total in service.totals) {
        if (!total.isCompleted) total.complete(0);
      }
      auth.dispose();
    });
    test(
      'summary fetches current month and independent authoritative total',
      () async {
        final pending = controller.load();
        expect(controller.loading, true);
        expect(service.scopes.single, (
          'one@example.com',
          DataStorageLocation.cloud,
          'a',
          false,
        ));
        service.finish(0, total: 1000);
        await pending;
        expect(controller.data!.total, 1000);
        expect(controller.data!.month, 5);
        expect(controller.loading, false);
      },
    );
    test('out-of-order requests cannot overwrite a newer result', () async {
      final first = controller.load();
      final second = controller.load(force: true);
      expect(service.reads.length, 1);
      service.finish(0, total: 100);
      await first;
      await Future<void>.delayed(Duration.zero);
      expect(
        controller.data,
        null,
      ); // A queued refresh must not publish the old snapshot.
      service.finish(1, total: 200);
      await second;
      expect(controller.data!.total, 200);
    });
    test(
      'ordinary concurrent loads share one month query and one total query',
      () async {
        final first = controller.load();
        final others = List.generate(8, (_) => controller.load());
        expect(others.every((future) => identical(future, first)), true);
        expect(service.reads.length, 1);
        expect(service.totals.length, 1);
        service.finish(0);
        await Future.wait([first, ...others]);
        final fresh = controller.load();
        expect(
          service.reads.length,
          2,
        ); // No long-lived stale cache after completion.
        service.finish(1);
        await fresh;
      },
    );
    test('multiple forced refreshes queue just one fresh read', () async {
      final first = controller.load();
      final forced = List.generate(6, (_) => controller.load(force: true));
      service.finish(0);
      await first;
      await Future<void>.delayed(Duration.zero);
      expect(service.reads.length, 2);
      service.finish(1, total: 222);
      await Future.wait(forced);
      expect(controller.data!.total, 222);
    });
    test(
      'account switch clears data and ignores the previous account response',
      () async {
        final pending = controller.load();
        auth.change(account: 'two@example.com');
        service.finish(0);
        await pending;
        expect(controller.data, null);
        await controller.load();
        expect(service.reads.length, 1);
      },
    );
    test(
      'storage switch reloads only the selected storage and ignores old response',
      () async {
        final old = controller.load();
        auth.change(location: DataStorageLocation.local);
        expect(service.scopes.last.$2, DataStorageLocation.local);
        service.finish(1, total: 20);
        await Future<void>.delayed(Duration.zero);
        service.finish(0, total: 999);
        await old;
        expect(controller.data!.total, 20);
      },
    );
    test('dispose safely ignores pending responses', () async {
      final pending = controller.load();
      controller.dispose();
      service.finish(0);
      await pending;
      expect(controller.data, null);
    });
    test('failed reads expose retry state and retry can recover', () async {
      final pending = controller.load();
      service.reads[0].completeError(StateError('offline'));
      service.totals[0].complete(0);
      await pending;
      expect(controller.error, isA<StateError>());
      expect(controller.loading, false);
      final retry = controller.load();
      service.finish(1);
      await retry;
      expect(controller.error, null);
      expect(controller.data, isNotNull);
    });
    test('synchronous logout notification starts no remote work', () async {
      controller.addListener(() {
        if (controller.loading) auth.change(account: 'other@example.com');
      });
      await controller.load();
      expect(service.reads, isEmpty);
      expect(service.totals, isEmpty);
    });
    test(
      'history reads all dates and needs no second account-total request',
      () async {
        controller.dispose();
        controller = ControllerRecordStatistics(
          auth: auth,
          accountId: 'a',
          kind: RecordStatisticsKind.points,
          service: service,
          history: true,
        );
        final pending = controller.load();
        expect(service.scopes.single.$4, true);
        expect(service.totals, isEmpty);
        service.reads.single.complete([
          row(DateTime(2020), 100),
          row(DateTime.now(), -5),
        ]);
        await pending;
        expect(controller.data!.total, 95);
      },
    );
  });

  group('local statistics source', () {
    late Database db;
    late LocalDataStore store;
    late ServiceRecordStatistics service;
    var sequence = 0;
    const owner = 'one@example.com';
    Future<void> put(
      String id, {
      String user = owner,
      String account = 'a',
      String currency = 'TWD',
      num value = 10,
      DateTime? date,
      String table = TableNames.accountingDetail,
    }) => store.put(
      owner: user,
      resource: table,
      id: id,
      data: {
        'id': id,
        'account_id': account,
        'currency': currency,
        'value': value,
        'date': (date ?? now).toIso8601String(),
      },
    );
    Future<List<Map<String, dynamic>>> read({
      bool history = false,
      RecordStatisticsKind kind = RecordStatisticsKind.accounting,
    }) => service.read(
      owner: owner,
      storage: DataStorageLocation.local,
      accountId: 'a',
      kind: kind,
      now: now,
      currency: 'TWD',
      history: history,
    );
    setUp(() async {
      db = await databaseFactoryMemory.openDatabase('statistics-${sequence++}');
      store = LocalDataStore.withDatabase(db);
      service = ServiceRecordStatistics(localStore: store);
    });
    tearDown(() => db.close());
    test(
      'local month excludes other users, accounts, currencies and months',
      () async {
        await put('mine');
        await put('other-owner', user: 'two@example.com');
        await put('other-account', account: 'b');
        await put('USD', currency: 'USD');
        await put('old', date: DateTime(2026, 9, 30));
        await put('next', date: DateTime(2026, 11));
        expect((await read()).map((r) => r['id']), ['mine']);
        expect((await read(history: true)).length, 3);
      },
    );
    test(
      'local total includes all historical dates for the same currency',
      () async {
        await put('old', date: DateTime(2020), value: 100);
        await put('new', value: -5);
        await put('usd', currency: 'USD', value: 999);
        expect(
          await service.readTotal(
            owner: owner,
            storage: DataStorageLocation.local,
            accountId: 'a',
            kind: RecordStatisticsKind.accounting,
            currency: 'TWD',
          ),
          95,
        );
      },
    );
    test(
      'points read only points resource and do not apply currency filtering',
      () async {
        await put('finance');
        await put(
          'points',
          table: TableNames.pointRecordDetail,
          currency: '',
          value: -2,
        );
        expect(
          (await read(kind: RecordStatisticsKind.points)).single['value'],
          -2,
        );
      },
    );
  });
}
