import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/accounting/controller_accounting_list.dart';
import 'package:life_pilot/accounting/model_accounting_account.dart';
import 'package:life_pilot/accounting/service_accounting.dart';
import 'package:life_pilot/auth/controller_auth.dart';
import 'package:life_pilot/local_storage/local_data_store.dart';

class _Auth extends ControllerAuth {
  String account = 'a@example.com';
  DataStorageLocation storage = DataStorageLocation.cloud;
  int revision = 0;
  @override
  String get currentAccount => account;
  @override
  DataStorageLocation get preferredStorage => storage;
  @override
  int get personalDataRevision => revision;
}

class _Service extends ServiceAccounting {
  final calls = <(String, String)>[];
  final pending = <Completer<String>>[];
  List<ModelAccountingAccount> rows = [];
  void Function()? onRead;
  @override
  Future<String> fetchLatestAccount({
    required String user,
    required String category,
  }) {
    calls.add((user, category));
    final done = Completer<String>();
    pending.add(done);
    onRead?.call();
    return done.future;
  }

  @override
  Future<List<ModelAccountingAccount>> fetchAccounts({
    required String user,
    String? category,
    int? projectLimit,
    bool includeGraph = true,
  }) async => rows;
}

ModelAccountingAccount _account(String? currency) => ModelAccountingAccount(
  id: 'a',
  accountName: 'Account',
  category: 'personal',
  currency: currency,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Auth auth;
  late _Service service;
  late ControllerAccountingList c;
  setUp(() {
    auth = _Auth();
    service = _Service();
    c = ControllerAccountingList(service: service, auth: auth);
  });
  tearDown(() {
    if (!c.notifierDisposed) c.dispose();
    auth.dispose();
  });

  test(
    'concurrent fallback reads query once and notify only one change',
    () async {
      var notifications = 0;
      c.addListener(() => notifications++);
      final a = c.loadMainCurrency(), b = c.loadMainCurrency();
      expect(service.calls, [('a@example.com', 'personal')]);
      service.pending.single.complete('TWD');
      await Future.wait([a, b]);
      expect(c.mainCurrency, 'TWD');
      expect(notifications, 1);
    },
  );

  test(
    'known account currency avoids reads and unchanged notifications',
    () async {
      c.accounts = [_account('USD')];
      var notifications = 0;
      c.addListener(() => notifications++);
      await c.loadMainCurrency();
      await c.loadMainCurrency();
      expect(service.calls, isEmpty);
      expect(c.mainCurrency, 'USD');
      expect(notifications, 1);
    },
  );

  test(
    'completed fallback is not cached as a permanent currency value',
    () async {
      final a = c.loadMainCurrency();
      service.pending[0].complete('TWD');
      await a;
      final b = c.loadMainCurrency();
      expect(service.calls, hasLength(2));
      service.pending[1].complete('USD');
      await b;
      expect(c.mainCurrency, 'USD');
    },
  );

  test(
    'newly loaded account currency wins over the pending fallback',
    () async {
      final old = c.loadMainCurrency();
      service.rows = [_account('JPY')];
      await c.loadAccounts();
      service.pending.single.complete('USD');
      await old;
      expect(c.mainCurrency, 'JPY');
    },
  );

  test(
    'classification changes use separate reads and discard old result',
    () async {
      final old = c.loadMainCurrency();
      await c.setCategory('project');
      final fresh = c.loadMainCurrency();
      expect(service.calls.map((call) => call.$2), ['personal', 'project']);
      service.pending[0].complete('USD');
      await old;
      expect(c.mainCurrency, isNull);
      service.pending[1].complete('JPY');
      await fresh;
      expect(c.mainCurrency, 'JPY');
    },
  );

  test(
    'returning to the original classification cannot reuse its old read',
    () async {
      final old = c.loadMainCurrency();
      await c.setCategory('project');
      await c.setCategory('personal');
      final fresh = c.loadMainCurrency();
      expect(service.calls, hasLength(2));
      service.pending[1].complete('JPY');
      await fresh;
      service.pending[0].complete('USD');
      await old;
      expect(c.mainCurrency, 'JPY');
    },
  );

  test('synchronous service re-entry joins the active fallback', () async {
    Future<void>? joined;
    service.onRead = () => joined = c.loadMainCurrency();
    final first = c.loadMainCurrency();
    expect(service.calls, hasLength(1));
    service.pending.single.complete('TWD');
    await Future.wait([first, joined!]);
    expect(c.mainCurrency, 'TWD');
  });

  test('current failure is returned and the next fallback can retry', () async {
    final failed = expectLater(c.loadMainCurrency(), throwsStateError);
    service.pending.single.completeError(StateError('offline'));
    await failed;
    expect(c.mainCurrency, isNull);
    final retry = c.loadMainCurrency();
    expect(service.calls, hasLength(2));
    service.pending.last.complete('USD');
    await retry;
    expect(c.mainCurrency, 'USD');
  });

  for (final action in ['account', 'storage', 'cleanup', 'dispose']) {
    for (final fails in [false, true]) {
      test('old currency after $action is ignored (failure=$fails)', () async {
        final old = c.loadMainCurrency();
        if (action == 'account') {
          auth.account = 'b@example.com';
        } else if (action == 'storage') {
          auth.storage = DataStorageLocation.local;
        } else if (action == 'cleanup') {
          auth.revision++;
        } else {
          c.dispose();
        }
        auth.notifyListeners();
        var notifications = 0;
        if (!c.notifierDisposed) c.addListener(() => notifications++);
        if (fails) {
          service.pending[0].completeError(StateError('obsolete'));
        } else {
          service.pending[0].complete('USD');
        }
        await old;
        expect(c.mainCurrency, isNull);
        expect(notifications, 0);
        if (!c.notifierDisposed) {
          final fresh = c.loadMainCurrency();
          expect(service.calls, hasLength(2));
          service.pending[1].complete('JPY');
          await fresh;
          expect(c.mainCurrency, 'JPY');
        }
      });
    }
  }
}
