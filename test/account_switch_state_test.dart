import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/accounting/controller_accounting_list.dart';
import 'package:life_pilot/accounting/model_accounting_account.dart';
import 'package:life_pilot/accounting/service_accounting.dart';
import 'package:life_pilot/auth/controller_auth.dart';
import 'package:life_pilot/apps/controller_page_main.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/point_record/controller_point_record_list.dart';
import 'package:life_pilot/point_record/model_point_record_account.dart';
import 'package:life_pilot/point_record/service_point_record.dart';
import 'package:life_pilot/utils/enum.dart';

class _FakeAuth extends ControllerAuth {
  _FakeAuth(this.account, {this.admin = false});

  String? account;
  bool admin;

  @override
  String? get currentAccount => account;

  @override
  bool get isSysAdmin => admin;
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

  test('account switch resets an admin-only selected page to home', () {
    final auth = _FakeAuth('admin@example.com', admin: true);
    final controller = ControllerPageMain(
      auth: auth,
      loc: lookupAppLocalizations(const Locale('zh')),
      initialLocale: const Locale('zh'),
    );

    controller.changePage(PageType.stock);
    expect(controller.selectedPage, PageType.stock);

    auth
      ..account = 'member@example.com'
      ..admin = false;
    controller.updateLocalization(
      lookupAppLocalizations(const Locale('zh')),
      const Locale('zh'),
      auth,
    );

    expect(controller.selectedPage, PageType.home);
    expect(controller.availablePages, isNot(contains(PageType.stock)));
    controller.dispose();
  });
}
