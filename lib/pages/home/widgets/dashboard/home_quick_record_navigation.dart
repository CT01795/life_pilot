import 'package:flutter/material.dart';
import 'package:life_pilot/accounting/page_accounting_detail.dart';
import 'package:life_pilot/accounting/service_accounting.dart';
import 'package:life_pilot/auth/model_auth_view.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/pages/home/controller_dashboard.dart';
import 'package:life_pilot/point_record/page_point_record_detail.dart';
import 'package:life_pilot/point_record/service_point_record.dart';
import 'package:provider/provider.dart';

/// Navigation stays in View; discard results from an obsolete user, storage
/// snapshot or account selection before opening a route or refreshing home.
class _HomeRecordScope {
  _HomeRecordScope(this.auth, this.dashboard, {required this.points})
    : dataScope = auth.dataScope,
      selection = points
          ? (
              dashboard.setting.pointAccountId,
              dashboard.setting.pointAccountName,
            )
          : (
              dashboard.setting.accountingAccountId,
              dashboard.setting.accountingAccountName,
            );

  final ModelAuthView auth;
  final ControllerDashboard dashboard;
  final bool points;
  final Object dataScope;
  final (String?, String?) selection;

  bool get isCurrent =>
      !auth.notifierDisposed &&
      !dashboard.notifierDisposed &&
      auth.dataScope == dataScope &&
      selection ==
          (points
              ? (
                  dashboard.setting.pointAccountId,
                  dashboard.setting.pointAccountName,
                )
              : (
                  dashboard.setting.accountingAccountId,
                  dashboard.setting.accountingAccountName,
                ));
}

Future<void> openHomeAccountingQuickAdd(BuildContext context) async {
  final loc = AppLocalizations.of(context)!;
  final dashboard = context.read<ControllerDashboard>();
  final auth = context.read<ModelAuthView>();
  final scope = _HomeRecordScope(auth, dashboard, points: false);
  final accountId = dashboard.setting.accountingAccountId;
  final user = auth.account;
  if (accountId == null || user == null) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(loc.selectAccount)));
    return;
  }

  final service = context.read<ServiceAccounting>();
  final accounts = await service.fetchAccounts(user: user, includeGraph: false);
  if (!context.mounted || !scope.isCurrent) return;
  final account = accounts
      .where((account) => account.id == accountId)
      .firstOrNull;
  if (account == null) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(loc.accountListLoadFailed)));
    return;
  }

  final saved = await Navigator.of(context).push<bool>(
    MaterialPageRoute(
      builder: (_) => PageAccountingDetail(
        service: service,
        account: account,
        returnAfterSubmit: true,
      ),
    ),
  );
  if (saved == true && context.mounted && scope.isCurrent) {
    await dashboard.refreshAccounting(accountId: accountId);
  }
}

Future<void> openHomeAccountingDetails(BuildContext context) async {
  final dashboard = context.read<ControllerDashboard>();
  final auth = context.read<ModelAuthView>();
  final scope = _HomeRecordScope(auth, dashboard, points: false);
  final accountId = dashboard.setting.accountingAccountId;
  final accountName = dashboard.setting.accountingAccountName;
  final user = auth.account;
  if ((accountId == null && accountName == null) || user == null) return;
  final service = context.read<ServiceAccounting>();
  final accounts = await service.fetchAccounts(user: user, includeGraph: false);
  if (!context.mounted || !scope.isCurrent) return;
  final account = accounts
      .where((item) => item.id == accountId || item.accountName == accountName)
      .firstOrNull;
  if (account == null) return;
  await Navigator.of(context).push<bool>(
    MaterialPageRoute(
      builder: (_) => PageAccountingDetail(service: service, account: account),
    ),
  );
}

Future<void> openHomePointQuickAdd(BuildContext context) async {
  final loc = AppLocalizations.of(context)!;
  final dashboard = context.read<ControllerDashboard>();
  final auth = context.read<ModelAuthView>();
  final scope = _HomeRecordScope(auth, dashboard, points: true);
  final accountId = dashboard.setting.pointAccountId;
  final user = auth.account;
  if (accountId == null || user == null) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(loc.selectAccount)));
    return;
  }

  final service = context.read<ServicePointRecord>();
  final accounts = await service.fetchAccounts(user: user, includeGraph: false);
  if (!context.mounted || !scope.isCurrent) return;
  final account = accounts
      .where((account) => account.id == accountId)
      .firstOrNull;
  if (account == null) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(loc.accountListLoadFailed)));
    return;
  }

  final saved = await Navigator.of(context).push<bool>(
    MaterialPageRoute(
      builder: (_) => PagePointRecordDetail(
        service: service,
        account: account,
        returnAfterSubmit: true,
      ),
    ),
  );
  if (saved == true && context.mounted && scope.isCurrent) {
    await dashboard.refreshPoints(accountId: accountId);
  }
}

Future<void> openHomePointDetails(BuildContext context) async {
  final dashboard = context.read<ControllerDashboard>();
  final auth = context.read<ModelAuthView>();
  final scope = _HomeRecordScope(auth, dashboard, points: true);
  final accountId = dashboard.setting.pointAccountId;
  final accountName = dashboard.setting.pointAccountName;
  final user = auth.account;
  if ((accountId == null && accountName == null) || user == null) return;
  final service = context.read<ServicePointRecord>();
  final accounts = await service.fetchAccounts(user: user, includeGraph: false);
  if (!context.mounted || !scope.isCurrent) return;
  final account = accounts
      .where((item) => item.id == accountId || item.accountName == accountName)
      .firstOrNull;
  if (account == null) return;
  await Navigator.of(context).push<bool>(
    MaterialPageRoute(
      builder: (_) => PagePointRecordDetail(service: service, account: account),
    ),
  );
}
