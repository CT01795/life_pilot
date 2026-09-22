import 'package:flutter/material.dart';
import 'package:life_pilot/accounting/page_accounting_detail.dart';
import 'package:life_pilot/accounting/service_accounting.dart';
import 'package:life_pilot/auth/model_auth_view.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/pages/home/model/dashboard/model_dashboard.dart';
import 'package:life_pilot/point_record/page_point_record_detail.dart';
import 'package:life_pilot/point_record/service_point_record.dart';
import 'package:provider/provider.dart';

Future<void> openHomeAccountingQuickAdd(BuildContext context) async {
  final loc = AppLocalizations.of(context)!;
  final dashboard = context.read<ModelDashboard>();
  final auth = context.read<ModelAuthView>();
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
  if (!context.mounted) return;
  final matches = accounts.where((account) => account.id == accountId);
  if (matches.isEmpty) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(loc.accountListLoadFailed)));
    return;
  }

  final saved = await Navigator.of(context).push<bool>(
    MaterialPageRoute(
      builder: (_) => PageAccountingDetail(
        service: service,
        account: matches.first,
        returnAfterSubmit: true,
      ),
    ),
  );
  if (saved == true && context.mounted) {
    await dashboard.refreshAccounting(accountId: accountId);
  }
}

Future<void> openHomeAccountingDetails(BuildContext context) async {
  final dashboard = context.read<ModelDashboard>();
  final auth = context.read<ModelAuthView>();
  final accountId = dashboard.setting.accountingAccountId;
  final accountName = dashboard.setting.accountingAccountName;
  final user = auth.account;
  if ((accountId == null && accountName == null) || user == null) return;
  final service = context.read<ServiceAccounting>();
  final accounts = await service.fetchAccounts(user: user, includeGraph: false);
  if (!context.mounted) return;
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
  final dashboard = context.read<ModelDashboard>();
  final auth = context.read<ModelAuthView>();
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
  if (!context.mounted) return;
  final matches = accounts.where((account) => account.id == accountId);
  if (matches.isEmpty) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(loc.accountListLoadFailed)));
    return;
  }

  final saved = await Navigator.of(context).push<bool>(
    MaterialPageRoute(
      builder: (_) => PagePointRecordDetail(
        service: service,
        account: matches.first,
        returnAfterSubmit: true,
      ),
    ),
  );
  if (saved == true && context.mounted) {
    await dashboard.refreshPoints(accountId: accountId);
  }
}

Future<void> openHomePointDetails(BuildContext context) async {
  final dashboard = context.read<ModelDashboard>();
  final auth = context.read<ModelAuthView>();
  final accountId = dashboard.setting.pointAccountId;
  final accountName = dashboard.setting.pointAccountName;
  final user = auth.account;
  if ((accountId == null && accountName == null) || user == null) return;
  final service = context.read<ServicePointRecord>();
  final accounts = await service.fetchAccounts(user: user, includeGraph: false);
  if (!context.mounted) return;
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
