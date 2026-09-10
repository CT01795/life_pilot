import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/accounting/controller_accounting_list.dart';
import 'package:life_pilot/accounting/model_accounting_account.dart';
import 'package:life_pilot/accounting/service_accounting.dart';
import 'package:life_pilot/auth/controller_auth.dart';
import 'package:life_pilot/point_record/controller_point_record_list.dart';
import 'package:life_pilot/point_record/model_point_record_account.dart';
import 'package:life_pilot/point_record/service_point_record.dart';

class _FakeAuth extends ControllerAuth {
  _FakeAuth(this.account);

  String? account;

  @override
  String? get currentAccount => account;
}

class _DelayedAccountingService extends ServiceAccounting {
  final response = Completer<List<ModelAccountingAccount>>();

  @override
  Future<List<ModelAccountingAccount>> fetchAccounts({
    required String user,
    String? category,
    int? projectLimit,
    bool includeGraph = true,
  }) =>
      response.future;
}

class _DelayedPointService extends ServicePointRecord {
  final response = Completer<List<ModelPointRecordAccount>>();

  @override
  Future<List<ModelPointRecordAccount>> fetchAccounts({
    required String user,
    String? category,
    int? projectLimit,
    bool includeGraph = true,
  }) =>
      response.future;
}

void main() {
  test('old accounting request cannot restore the previous user accounts',
      () async {
    final auth = _FakeAuth('old@example.com');
    final service = _DelayedAccountingService();
    final controller = ControllerAccountingList(service: service, auth: auth);

    final request = controller.loadAccounts();
    auth.account = 'new@example.com';
    controller.updateAuth(auth, notify: false);
    service.response.complete([
      ModelAccountingAccount(
        id: 'old',
        accountName: 'Old account',
        category: 'personal',
      ),
    ]);
    await request;

    expect(controller.accounts, isEmpty);
    expect(controller.isLoading, isFalse);
  });

  test('old point request cannot restore the previous user accounts', () async {
    final auth = _FakeAuth('old@example.com');
    final service = _DelayedPointService();
    final controller = ControllerPointRecordList(service: service, auth: auth);

    final request = controller.loadAccounts();
    auth.account = 'new@example.com';
    controller.updateAuth(auth, notify: false);
    service.response.complete([
      ModelPointRecordAccount(
        id: 'old',
        accountName: 'Old account',
        category: 'personal',
      ),
    ]);
    await request;

    expect(controller.accounts, isEmpty);
    expect(controller.isLoading, isFalse);
  });
}
