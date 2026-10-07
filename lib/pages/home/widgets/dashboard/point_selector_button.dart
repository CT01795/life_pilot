import 'package:flutter/material.dart';
import 'package:life_pilot/auth/model_auth_view.dart';
import 'package:life_pilot/apps/controller_page_main.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/pages/home/model/dashboard/model_dashboard.dart';
import 'package:life_pilot/pages/home/widgets/dashboard/dashboard_account_selector.dart';
import 'package:life_pilot/point_record/service_point_record.dart';
import 'package:life_pilot/utils/enum.dart';
import 'package:provider/provider.dart';

class PointSelectorButton extends StatelessWidget {
  const PointSelectorButton({super.key});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final accountName = context.select<ModelDashboard, String?>(
      (dashboard) => dashboard.setting.pointAccountName,
    );
    final accountId = context.select<ModelDashboard, String?>(
      (dashboard) => dashboard.setting.pointAccountId,
    );
    final dashboard = context.read<ModelDashboard>();
    final auth = context.read<ModelAuthView>();

    return DashboardAccountSelector(
      icon: Icons.stars,
      selectedAccountId: accountId,
      selectedAccountName: accountName,
      accountPageLabel: loc.pointsRecord,
      loadAccounts: () async {
        final accounts = await context.read<ServicePointRecord>().fetchAccounts(
          user: auth.account ?? '',
          projectLimit: 2,
          includeGraph: false,
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
