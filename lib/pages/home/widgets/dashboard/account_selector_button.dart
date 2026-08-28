import 'package:flutter/material.dart';
import 'package:life_pilot/accounting/service_accounting.dart';
import 'package:life_pilot/apps/controller_page_main.dart';
import 'package:life_pilot/auth/model_auth_view.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/pages/home/model/dashboard/model_dashboard.dart';
import 'package:life_pilot/utils/const.dart';
import 'package:life_pilot/utils/enum.dart';
import 'package:provider/provider.dart';

class AccountSelectorButton extends StatefulWidget {
  const AccountSelectorButton({
    super.key,
  });

  @override
  State<AccountSelectorButton> createState() => _AccountSelectorButtonState();
}

class _AccountSelectorButtonState extends State<AccountSelectorButton> {
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final accountName = context.select<ModelDashboard, String?>(
      (dashboard) => dashboard.setting.accountingAccountName,
    );
    final accountId = context.select<ModelDashboard, String?>(
      (dashboard) => dashboard.setting.accountingAccountId,
    );
    final dashboard = context.read<ModelDashboard>();
    final auth = context.read<ModelAuthView>();

    return Tooltip(
      message: loc.selectAccount,
      child: ActionChip(
        avatar: const Icon(
          Icons.account_balance_wallet,
        ),
        label: Text(
          accountName ?? loc.selectAccount,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        onPressed: _isLoading
            ? null
            : () async {
                setState(() => _isLoading = true);
                try {
                  final accounts =
                      await context.read<ServiceAccounting>().fetchAccounts(
                            user: auth.account ?? '',
                            projectLimit: 2,
                          );

                  if (!context.mounted) return;

                  if (accounts.isEmpty) {
                    await showDialog<void>(
                      context: context,
                      builder: (_) => AlertDialog(
                        content: Text(loc.accountListEmpty),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: Text(loc.cancel),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.pop(context);
                              context
                                  .read<ControllerPageMain>()
                                  .changePage(PageType.accountRecords);
                            },
                            child: Text(loc.accountRecords),
                          ),
                        ],
                      ),
                    );
                    return;
                  }

                  final selected = await showDialog<Map<String, String>>(
                    context: context,
                    builder: (_) {
                      return SimpleDialog(
                        title: Text(loc.selectAccount),
                        children: [
                          if (accountId != null)
                            SimpleDialogOption(
                              onPressed: () => Navigator.pop(
                                context,
                                const <String, String>{},
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.clear),
                                  const SizedBox(width: 12),
                                  Text(loc.clear),
                                ],
                              ),
                            ),
                          ...accounts.map((a) {
                            return SimpleDialogOption(
                              child: ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text(a.accountName),
                                subtitle: Text(
                                  _categoryLabel(loc, a.category),
                                ),
                              ),
                              onPressed: () {
                                Navigator.pop(
                                  context,
                                  {
                                    Fields.id: a.id,
                                    'name': a.accountName,
                                  },
                                );
                              },
                            );
                          }),
                        ],
                      );
                    },
                  );

                  if (selected == null || auth.account == null) return;

                  try {
                    await dashboard.changeAccountingAccount(
                      account: auth.account!,
                      accountId: selected[Fields.id],
                      accountName: selected['name'],
                    );
                  } catch (_) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(loc.dashboardSettingSaveFailed)),
                      );
                    }
                  }
                } catch (_) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(loc.accountListLoadFailed)),
                    );
                  }
                } finally {
                  if (mounted) setState(() => _isLoading = false);
                }
              },
      ),
    );
  }

  String _categoryLabel(AppLocalizations loc, String category) {
    return switch (category) {
      'project' => loc.accountProject,
      'master' => loc.accountMaster,
      _ => loc.accountPersonal,
    };
  }
}
