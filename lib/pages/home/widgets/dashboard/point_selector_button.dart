import 'package:flutter/material.dart';
import 'package:life_pilot/auth/model_auth_view.dart';
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
    final dashboard = context.watch<ModelDashboard>();
    final auth = context.read<ModelAuthView>();

    return Tooltip(
      message: loc.selectAccount,
      child: ActionChip(
        avatar: const Icon(
          Icons.stars,
        ),
        label: Text(
          dashboard.setting.pointAccountName ?? loc.selectAccount,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        onPressed: _isLoading
            ? null
            : () async {
          setState(() => _isLoading = true);
          try {
            final accounts = await context.read<ServicePointRecord>().fetchAccounts(
                  user: auth.account ?? '',
                  category: AccountCategory.personal.name,
                );

            if (!context.mounted) return;

            final selected = await showDialog<Map<String, String>>(
            context: context,
            builder: (_) {
              return SimpleDialog(
                title: Text(
                  loc.selectAccount,
                ),
                children: accounts.map((a) {
                  return SimpleDialogOption(
                    child: Text(
                      a.accountName,
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
                }).toList(),
              );
            },
          );

            if (selected == null || auth.account == null) return;

            try {
              await dashboard.changePointAccount(
                account: auth.account!,
                accountId: selected[Fields.id]!,
                accountName: selected['name']!,
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
}
