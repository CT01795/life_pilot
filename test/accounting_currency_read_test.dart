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
  int listCalls = 0;
  final pending = <Completer<List<ModelAccountingAccount>>>[];
  String? createdCurrency;

  @override
  Future<List<ModelAccountingAccount>> fetchAccounts({
    required String user,
    String? category,
    int? projectLimit,
  }) {
    listCalls++;
    final result = Completer<List<ModelAccountingAccount>>();
    pending.add(result);
    return result.future;
  }

  @override
  Future<ModelAccountingAccount> createAccount({
    required String name,
    required String user,
    required String? currency,
    required String category,
    String? eventId,
  }) async {
    createdCurrency = currency;
    return ModelAccountingAccount(
      id: 'new',
      accountName: name,
      category: category,
      currency: currency,
    );
  }
}

ModelAccountingAccount _account(String currency) => ModelAccountingAccount(
  id: 'a',
  accountName: 'Account',
  category: 'personal',
  currency: currency,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Auth auth;
  late _Service service;
  late ControllerAccountingList controller;
  setUp(() {
    auth = _Auth();
    service = _Service();
    controller = ControllerAccountingList(service: service, auth: auth);
  });
  tearDown(() {
    if (!controller.notifierDisposed) controller.dispose();
    auth.dispose();
  });

  test('concurrent currency reads reuse one account-list request', () async {
    final first = controller.loadMainCurrency();
    final second = controller.loadMainCurrency();
    expect(service.listCalls, 1);
    service.pending.single.complete([_account('USD')]);
    await Future.wait([first, second]);
    expect(controller.mainCurrency, 'USD');
  });

  test('an already loaded account list avoids another request', () async {
    final loading = controller.loadAccounts();
    service.pending.single.complete([_account('JPY')]);
    await loading;
    await controller.loadMainCurrency();
    expect(service.listCalls, 1);
    expect(controller.mainCurrency, 'JPY');
  });

  test('a confirmed empty list uses the default currency', () async {
    final loading = controller.loadMainCurrency();
    service.pending.single.complete([]);
    await loading;
    expect(service.listCalls, 1);
    expect(controller.mainCurrency, 'TWD');
  });

  test('first account creation reuses the empty list and TWD', () async {
    final creation = controller.createAccount(name: 'First');
    service.pending.first.complete([]);
    await Future<void>.delayed(Duration.zero);
    service.pending.last.complete([_account('TWD')]);
    await creation;
    expect(service.createdCurrency, 'TWD');
    expect(service.listCalls, 2); // Initial list plus post-create refresh.
  });

  test(
    'an old account-list result cannot publish after account switch',
    () async {
      final old = controller.loadMainCurrency();
      auth.account = 'b@example.com';
      auth.notifyListeners();
      service.pending.first.complete([_account('USD')]);
      await old;
      expect(controller.mainCurrency, isNull);
    },
  );
}
