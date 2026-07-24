import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:life_pilot/apps/controller_page_main.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/pages/home/model/accounting/income_expense_item.dart';
import 'package:life_pilot/pages/home/model/dashboard/model_dashboard.dart';
import 'package:life_pilot/pages/home/widgets/dashboard/account_selector_button.dart';
import 'package:life_pilot/pages/home/widgets/dashboard/dashboard_card_header.dart';
import 'package:life_pilot/utils/const.dart';
import 'package:life_pilot/utils/enum.dart';
import 'package:provider/provider.dart';

class IncomeExpenseSummaryCard extends StatelessWidget {
  const IncomeExpenseSummaryCard({super.key});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final records = context.select<ModelDashboard, List<IncomeExpenseItem>>(
      (m) => m.state.todayIncomeExpense,
    );

    final total = records.fold<int>(
      0,
      (sum, e) => sum + e.value,
    );

    String currency =
        records.isNotEmpty ? (records[0].currency ?? 'TWD') : 'TWD';

    final formatter = NumberFormat('#,###');

    return Card(
      color: Color(0xFFE5DDED),
      elevation: 2,
      child: Padding(
        padding: Insets.all12,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DashboardCardHeader(
              icon: Icons.account_balance_wallet,
              title: loc.accountRecords,
              trailing:const AccountSelectorButton(),
            ),
            Gaps.h16,
            ListTile(
              dense: true,
              title: Text(loc.todayIncomeExpense, style: Theme.of(context).textTheme.titleMedium),
              trailing: Text(
                '${formatter.format(total)} $currency',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: total < 0
                          ? Colors.red // 收入
                          : Colors.black, // 支出
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ),
            const Divider(),
            if (records.isEmpty)
              ListTile(
                leading: Icon(Icons.info_outline),
                 title: Text(loc.noInfoAvailable),
              )
            else
              ...records.map(
              (record) => ListTile(
                dense: true,
                title: Text(record.description,
                    style: Theme.of(context).textTheme.titleMedium),
                subtitle: Text(
                    record.group == null || record.group!.isEmpty ? '' : record.group!,
                    style: Theme.of(context).textTheme.titleMedium),
                trailing: Text(
                  '${formatter.format(record.value)} $currency',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: record.value < 0
                            ? Colors.red // 收入
                            : Colors.black, // 支出
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () {
                  context
                      .read<ControllerPageMain>()
                      .changePage(PageType.accountRecords);
                },
                child: Text(loc.clickHereToSeeMore),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
