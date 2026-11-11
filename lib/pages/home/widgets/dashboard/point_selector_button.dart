import 'package:flutter/material.dart';
import 'package:life_pilot/accounting/service_ledger_sharing.dart';
import 'package:life_pilot/auth/model_auth_view.dart';
import 'package:life_pilot/apps/controller_page_main.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/pages/home/controller_dashboard.dart';
import 'package:life_pilot/pages/home/widgets/dashboard/dashboard_account_selector.dart';
import 'package:life_pilot/point_record/service_point_record.dart';
import 'package:life_pilot/utils/enum.dart';
import 'package:provider/provider.dart';

class PointSelectorButton extends StatelessWidget {
  const PointSelectorButton({super.key});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final shared = context.select(
      (ControllerDashboard c) => c.sharedLedger(points: true),
    );
    final accountName = context.select<ControllerDashboard, String?>(
      (dashboard) => dashboard.setting.pointAccountName,
    );
    final accountId = context.select<ControllerDashboard, String?>(
      (dashboard) => dashboard.setting.pointAccountId,
    );
    final dashboard = context.read<ControllerDashboard>();
    final auth = context.watch<ModelAuthView>();

    return DashboardAccountSelector(
      sharedKind: auth.dataScope.storage.name == 'cloud'
          ? LedgerKind.points
          : null,
      onSharedChanged: (option) => dashboard.selectSharedLedger(
        points: true,
        selection: (id: option.id, name: option.name),
      ),
      icon: Icons.stars,
      selectedAccountId: shared?.id ?? accountId,
      selectedAccountName: shared == null
          ? accountName
          : '${shared.name} · ${loc.ledgerSharedAccount}',
      accountPageLabel: loc.pointsRecord,
      loadAccounts: () async {
        final accounts = await context.read<ServicePointRecord>().fetchAccounts(
          user: auth.account ?? '',
          projectLimit: 2,
        );
        return accounts
            .map(
              (account) => DashboardAccountOption(
                id: account.id,
                name: account.accountName,
                category: account.category,
              ),
            )
            .toList(growable: false);
      },
      onChanged: (selected) async {
        final user = auth.account;
        if (user == null) return;
        await dashboard.selectSharedLedger(points: true, selection: null);
        await dashboard.changePointAccount(
          account: user,
          accountId: selected?.id,
          accountName: selected?.name,
        );
      },
      onOpenAccountPage: () =>
          context.read<ControllerPageMain>().changePage(PageType.pointsRecord),
    );
  }
}
