import 'package:flutter/material.dart';
import 'package:life_pilot/accounting/service_accounting.dart';
import 'package:life_pilot/auth/model_auth_view.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/pages/home/model/dashboard/model_dashboard.dart';
import 'package:life_pilot/utils/enum.dart';
import 'package:provider/provider.dart';

class AccountSelectorButton extends StatelessWidget {
  const AccountSelectorButton({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final dashboard = context.watch<ModelDashboard>();
    final auth = context.read<ModelAuthView>();

    return Tooltip(
      message: loc.selectAccount,
      child: ActionChip(
        avatar: const Icon(
          Icons.account_balance_wallet,
        ),
        label: Text(
          dashboard.setting.accountingAccountName ?? loc.selectAccount,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        onPressed: () async {
          final accounts =
              await context.read<ServiceAccounting>().fetchAccounts(user: auth.account ?? '', category: AccountCategory.personal.name);

          final selected = await showDialog<Map<String,String>>(
            context: context,
            builder: (_) {
              return SimpleDialog(
                title: Text(loc.selectAccount),
                children: accounts.map((a) {
                  return SimpleDialogOption(
                    child: Text(
                      a.accountName,
                    ),
                    onPressed: () {
                      Navigator.pop(
                        context,
                        {
                          'id': a.id,
                          'name': a.accountName,
                        },
                      );
                    },
                  );
                }).toList(),
              );
            },
          );

          if (selected == null || auth.account == null) {
            return;
          }

          await dashboard.changeAccountingAccount(
            account: auth.account!,
            accountId: selected['id']!,
            accountName: selected['name']!,
          );
        },
      ),
    );
  }
}
