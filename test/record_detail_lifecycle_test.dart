import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/accounting/controller_accounting_detail.dart';
import 'package:life_pilot/accounting/model_accounting_detail.dart';
import 'package:life_pilot/accounting/service_accounting.dart';
import 'package:life_pilot/auth/controller_auth.dart';
import 'package:life_pilot/local_storage/local_data_store.dart';
import 'package:life_pilot/point_record/controller_point_record_detail.dart';
import 'package:life_pilot/point_record/model_point_record_detail.dart';
import 'package:life_pilot/point_record/service_point_record.dart';
import 'package:life_pilot/utils/model_record_history_page.dart';

class _Auth extends ControllerAuth {
  String account = 'a@example.com';
  DataStorageLocation storage = DataStorageLocation.cloud;

  @override
  String get currentAccount => account;

  @override
  DataStorageLocation get preferredStorage => storage;

  void changeAccount() {
    account = 'b@example.com';
    notifyListeners();
  }
}

class _Accounting extends ServiceAccounting {
  final requests = <Completer<ModelRecordHistoryPage<ModelAccountingDetail>>>[];
  final includeReserved = <bool>[];
  final deleted = <String>[];

  @override
  Future<void> deleteAccountingDetail({required String detailId}) async {
    deleted.add(detailId);
  }

  @override
  Future<ModelRecordHistoryPage<ModelAccountingDetail>> fetchRecordsPage({
    required String accountId,
    required String type,
    required DateTime dateFrom,
    required DateTime dateTo,
    bool includeLatestFallback = false,
    bool includeReservedRecords = true,
  }) {
    includeReserved.add(includeReservedRecords);
    final request = Completer<ModelRecordHistoryPage<ModelAccountingDetail>>();
    requests.add(request);
    return request.future;
  }
}

class _Points extends ServicePointRecord {
  final requests =
      <Completer<ModelRecordHistoryPage<ModelPointRecordDetail>>>[];
  final includeReserved = <bool>[];
  final deleted = <String>[];

  @override
  Future<void> deletePointRecordDetail({required String detailId}) async {
    deleted.add(detailId);
  }

  @override
  Future<ModelRecordHistoryPage<ModelPointRecordDetail>> fetchRecordsPage({
    required String accountId,
    required String type,
    required DateTime dateFrom,
    required DateTime dateTo,
    bool includeLatestFallback = false,
    bool includeReservedRecords = true,
  }) {
    includeReserved.add(includeReservedRecords);
    final request = Completer<ModelRecordHistoryPage<ModelPointRecordDetail>>();
    requests.add(request);
    return request.future;
  }
}

ModelAccountingDetail _accountingRow(
  String id,
  DateTime date, {
  String category = 'food',
}) => ModelAccountingDetail(
  id: id,
  accountId: 'account',
  createdAt: date,
  date: date,
  primaryCategory: category,
  description: id,
  type: 'balance',
  value: 1,
  currency: 'TWD',
  balance: 2,
);

ModelPointRecordDetail _pointRow(String id, DateTime date) =>
    ModelPointRecordDetail(
      id: id,
      accountId: 'account',
      createdAt: date,
      date: date,
      primaryCategory: 'task',
      description: id,
      type: 'points',
      value: 1,
      points: 2,
    );

void main() {
  test(
    'accounting delete while loading replaces the stale detail page',
    () async {
      final service = _Accounting();
      final controller = ControllerAccountingDetail(
        service: service,
        auth: null,
        accountId: 'account',
      );
      addTearDown(controller.dispose);
      final initial = controller.loadToday();
      final deleting = controller.deleteAccountingDetail('deleted');
      await Future<void>.delayed(Duration.zero);
      expect(service.deleted, ['deleted']);
      expect(service.requests, hasLength(1));
      final date = DateTime.now();
      service.requests.first.complete(
        ModelRecordHistoryPage(
          rows: [_accountingRow('deleted', date)],
          total: 10,
          nextBefore: date,
          nextDate: null,
        ),
      );
      await initial;
      await Future<void>.delayed(Duration.zero);
      expect(controller.todayRecords, isEmpty);
      expect(service.requests, hasLength(2));
      service.requests.last.complete(
        ModelRecordHistoryPage(
          rows: [_accountingRow('fresh', date)],
          total: 2,
          nextBefore: date,
          nextDate: null,
        ),
      );
      await deleting;
      expect(controller.todayRecords.single.id, 'fresh');
    },
  );

  test('points delete while loading replaces the stale detail page', () async {
    final service = _Points();
    final controller = ControllerPointRecordDetail(
      service: service,
      auth: null,
      accountId: 'account',
    );
    addTearDown(controller.dispose);
    final initial = controller.loadToday();
    final deleting = controller.deletePointRecordDetail('deleted');
    await Future<void>.delayed(Duration.zero);
    expect(service.deleted, ['deleted']);
    expect(service.requests, hasLength(1));
    final date = DateTime.now();
    service.requests.first.complete(
      ModelRecordHistoryPage(
        rows: [_pointRow('deleted', date)],
        total: 10,
        nextBefore: date,
        nextDate: null,
      ),
    );
    await initial;
    await Future<void>.delayed(Duration.zero);
    expect(controller.todayRecords, isEmpty);
    expect(service.requests, hasLength(2));
    service.requests.last.complete(
      ModelRecordHistoryPage(
        rows: [_pointRow('fresh', date)],
        total: 2,
        nextBefore: date,
        nextDate: null,
      ),
    );
    await deleting;
    expect(controller.todayRecords.single.id, 'fresh');
  });

  test(
    'accounting pages include the next cursor without metadata probes',
    () async {
      final auth = _Auth();
      final service = _Accounting();
      final controller = ControllerAccountingDetail(
        service: service,
        auth: auth,
        accountId: 'account',
      );
      addTearDown(controller.dispose);
      final firstDate = DateTime(2026, 11, 16);
      final nextDate = DateTime(2026, 9, 15);

      final initial = controller.loadToday();
      expect(service.requests, hasLength(1));
      service.requests.single.complete(
        ModelRecordHistoryPage(
          rows: [_accountingRow('new', firstDate)],
          total: 10,
          nextBefore: DateTime(2026, 10, 17),
          nextDate: nextDate,
        ),
      );
      await initial;
      expect(controller.hasMore, isTrue);

      final more = controller.loadMore();
      expect(service.requests, hasLength(2));
      service.requests.last.complete(
        ModelRecordHistoryPage(
          rows: [_accountingRow('old', nextDate)],
          total: 10,
          nextBefore: DateTime(2026, 8, 16),
          nextDate: null,
        ),
      );
      await more;
      expect(controller.todayRecords.map((row) => row.id), ['new', 'old']);
      expect(controller.hasMore, isFalse);
      expect(service.includeReserved, [true, false]);
    },
  );

  test(
    'one accounting load-more skips duplicate-only windows until a new row',
    () async {
      final auth = _Auth();
      final service = _Accounting();
      final controller = ControllerAccountingDetail(
        service: service,
        auth: auth,
        accountId: 'account',
      );
      addTearDown(controller.dispose);
      final recent = DateTime(2026, 7, 5);
      final reservedDate = DateTime(2026, 2, 11);
      final firstCursor = DateTime(2026, 7, 4);
      final secondCursor = DateTime(2026, 7, 3);

      final initial = controller.loadToday();
      service.requests.single.complete(
        ModelRecordHistoryPage(
          rows: [
            _accountingRow('recent', recent),
            _accountingRow('reserved', reservedDate, category: 'reserved'),
          ],
          total: 10,
          nextBefore: recent,
          nextDate: firstCursor,
        ),
      );
      await initial;
      expect(controller.todayRecords.map((row) => row.id), [
        'reserved',
        'recent',
      ]);

      final more = controller.loadMore();
      service.requests[1].complete(
        ModelRecordHistoryPage(
          rows: [
            _accountingRow('reserved', reservedDate, category: 'reserved'),
          ],
          total: 10,
          nextBefore: firstCursor,
          nextDate: secondCursor,
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect(service.requests, hasLength(3));
      service.requests[2].complete(
        ModelRecordHistoryPage(
          rows: [_accountingRow('older', secondCursor)],
          total: 10,
          nextBefore: secondCursor,
          nextDate: null,
        ),
      );
      await more;

      expect(controller.todayRecords.map((row) => row.id), [
        'reserved',
        'recent',
        'older',
      ]);
      expect(controller.hasMore, isFalse);
      expect(service.includeReserved, [true, false, false]);
    },
  );

  test('point pages include the next cursor without metadata probes', () async {
    final auth = _Auth();
    final service = _Points();
    final controller = ControllerPointRecordDetail(
      service: service,
      auth: auth,
      accountId: 'account',
    );
    addTearDown(controller.dispose);
    final firstDate = DateTime(2026, 11, 16);
    final nextDate = DateTime(2026, 9, 15);

    final initial = controller.loadToday();
    service.requests.single.complete(
      ModelRecordHistoryPage(
        rows: [_pointRow('new', firstDate)],
        total: 10,
        nextBefore: DateTime(2026, 10, 17),
        nextDate: nextDate,
      ),
    );
    await initial;
    final more = controller.loadMore();
    expect(service.requests, hasLength(2));
    service.requests.last.complete(
      ModelRecordHistoryPage(
        rows: [_pointRow('old', nextDate)],
        total: 10,
        nextBefore: DateTime(2026, 8, 16),
        nextDate: null,
      ),
    );
    await more;
    expect(controller.todayRecords.map((row) => row.id), ['new', 'old']);
    expect(controller.hasMore, isFalse);
    expect(service.includeReserved, [true, false]);
  });

  test('late accounting page is ignored after account switch', () async {
    final auth = _Auth();
    final service = _Accounting();
    final controller = ControllerAccountingDetail(
      service: service,
      auth: auth,
      accountId: 'account',
    );
    addTearDown(controller.dispose);

    final loading = controller.loadToday();
    auth.changeAccount();
    service.requests.single.complete(
      ModelRecordHistoryPage(
        rows: [_accountingRow('stale', DateTime(2026, 11, 16))],
        total: 1,
        nextBefore: DateTime(2026, 10, 17),
        nextDate: null,
      ),
    );
    await loading;
    expect(controller.todayRecords, isEmpty);
    expect(controller.isLoading, isFalse);
  });

  test('failed point page can retry', () async {
    final auth = _Auth();
    final service = _Points();
    final controller = ControllerPointRecordDetail(
      service: service,
      auth: auth,
      accountId: 'account',
    );
    addTearDown(controller.dispose);

    final failed = controller.loadToday();
    service.requests.single.completeError(StateError('offline'));
    await expectLater(failed, throwsStateError);
    expect(controller.isLoading, isFalse);

    final retried = controller.loadToday();
    service.requests.last.complete(
      ModelRecordHistoryPage(
        rows: [_pointRow('fresh', DateTime(2026, 11, 16))],
        total: 1,
        nextBefore: DateTime(2026, 10, 17),
        nextDate: null,
      ),
    );
    await retried;
    expect(controller.todayRecords.single.id, 'fresh');
  });
}
