import 'package:flutter/material.dart';
import 'package:life_pilot/auth/model_auth_view.dart';
import 'package:life_pilot/apps/controller_page_main.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/pages/home/model/dashboard/model_dashboard.dart';
import 'package:life_pilot/point_record/service_point_record.dart';
import 'package:life_pilot/utils/const.dart';
import 'package:life_pilot/utils/enum.dart';
import 'package:provider/provider.dart';

class PointSelectorButton extends StatefulWidget {
  const PointSelectorButton({
    super.key,
  });

  @override
  State<PointSelectorButton> createState() => _PointSelectorButtonState();
}

class _PointSelectorButtonState extends State<PointSelectorButton> {
  bool _isLoading = false;

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

    return Tooltip(
      message: loc.selectAccount,
      child: ActionChip(
        avatar: const Icon(
          Icons.stars,
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
                      await context.read<ServicePointRecord>().fetchAccounts(
                            user: auth.account ?? '',
                            projectLimit: 2,
                            includeGraph: false,
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
                                  .changePage(PageType.pointsRecord);
                            },
                            child: Text(loc.pointsRecord),
                          ),
                        ],
                      ),
                    );
                    return;
                  }

                  final selected = await showDialog<Map<String, String>>(
                    context: context,
                    builder: (dialogContext) {
                      final hasClearOption = accountId != null;
                      return AlertDialog(
                        title: Text(loc.selectAccount),
                        contentPadding:
                            const EdgeInsets.fromLTRB(12, 8, 12, 12),
                        content: ConstrainedBox(
                          constraints: const BoxConstraints(
                            maxWidth: 420,
                            maxHeight: 480,
                          ),
                          child: ListView.separated(
                            shrinkWrap: true,
                            itemCount:
                                accounts.length + (hasClearOption ? 1 : 0),
                            separatorBuilder: (_, __) =>
                                const Divider(height: 1),
                            itemBuilder: (_, index) {
                              if (hasClearOption && index == 0) {
                                return ListTile(
                                  leading: const Icon(Icons.clear),
                                  title: Text(loc.clear),
                                  onTap: () => Navigator.pop(
                                    dialogContext,
                                    const <String, String>{},
                                  ),
                                );
                              }
                              final accountIndex =
                                  index - (hasClearOption ? 1 : 0);
                              final account = accounts[accountIndex];
                              return ListTile(
                                title: Text(account.accountName),
                                subtitle: Text(
                                  _categoryLabel(loc, account.category),
                                ),
                                onTap: () => Navigator.pop(
                                  dialogContext,
                                  {
                                    Fields.id: account.id,
                                    'name': account.accountName,
                                  },
                                ),
                              );
                            },
                          ),
                        ),
                      );
                    },
                  );

                  if (selected == null || auth.account == null) return;

                  try {
                    await dashboard.changePointAccount(
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
