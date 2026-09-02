import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:life_pilot/apps/controller_page_main.dart';
import 'package:life_pilot/auth/model_auth_view.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/pages/home/model/accounting/income_expense_item.dart';
import 'package:life_pilot/pages/home/model/dashboard/model_dashboard.dart';
import 'package:life_pilot/pages/home/widgets/dashboard/account_selector_button.dart';
import 'package:life_pilot/pages/home/widgets/dashboard/dashboard_card_header.dart';
import 'package:life_pilot/pages/home/widgets/dashboard/dashboard_load_failure.dart';
import 'package:life_pilot/pages/home/widgets/dashboard/dashboard_section_loading.dart';
import 'package:life_pilot/utils/const.dart';
import 'package:life_pilot/utils/enum.dart';
import 'package:provider/provider.dart';

class IncomeExpenseSummaryCard extends StatelessWidget {
  const IncomeExpenseSummaryCard({super.key});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final records = context.select<ModelDashboard, List<IncomeExpenseItem>>(
      (m) => m.state.todayIncomeExpense,
    );
    final hasLoadFailed = context.select<ModelDashboard, bool>(
      (m) => m.hasFailed(DashboardSection.accounting),
    );
    final isLoading = context.select<ModelDashboard, bool>(
      (m) => m.isLoading(DashboardSection.accounting),
    );
    final hasSelectedAccount = context.select<ModelDashboard, bool>(
      (m) => m.setting.accountingAccountId != null,
    );

    final todayTotal = context.select<ModelDashboard, int>(
      (m) => m.state.todayAccountingTotal,
    );
    final accountTotal = context.select<ModelDashboard, int>(
      (m) => m.state.accountingTotal,
    );
    final currency = context.select<ModelDashboard, String>(
      (m) => m.state.accountingCurrency,
    );

    final formatter = NumberFormat('#,###');

    return Card(
      color: colorScheme.brightness == Brightness.dark
          ? colorScheme.surfaceContainerHigh
          : const Color(0xFFE5DDED),
      elevation: 2,
      child: Padding(
        padding: Insets.all12,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DashboardCardHeader(
              icon: Icons.account_balance_wallet,
              title: loc.accountRecords,
              trailing: const AccountSelectorButton(),
            ),
            if (!hasSelectedAccount)
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: Text(loc.selectAccount),
              )
            else ...[
              Gaps.h16,
              ListTile(
                dense: true,
                title: Text(
                  loc.totalAmount,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                trailing: Text(
                  '${formatter.format(accountTotal)} $currency',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: accountTotal < 0
                            ? colorScheme.error
                            : colorScheme.onSurface,
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ),
              ListTile(
                dense: true,
                title: Text(loc.todayIncomeExpense,
                    style: Theme.of(context).textTheme.titleMedium),
                trailing: Text(
                  '${formatter.format(todayTotal)} $currency',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: todayTotal < 0
                            ? colorScheme.error
                            : colorScheme.onSurface,
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ),
              const Divider(),
              if (isLoading && records.isNotEmpty)
                const LinearProgressIndicator(),
              if (hasLoadFailed)
                DashboardLoadFailure(
                  onRetry: () => context.read<ModelDashboard>().retrySection(
                        section: DashboardSection.accounting,
                        account: context.read<ModelAuthView>().account!,
                      ),
                )
              else if (isLoading && records.isEmpty)
                const DashboardSectionLoading()
              else if (records.isEmpty)
                ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: Text(loc.noInfoAvailable),
                )
              else
                ...records.take(5).map(
                      (record) => ListTile(
                        dense: true,
                        title: Text(record.description,
                            style: Theme.of(context).textTheme.titleMedium),
                        subtitle: Text(
                            record.group == null || record.group!.isEmpty
                                ? ''
                                : record.group!,
                            style: Theme.of(context).textTheme.titleMedium),
                        trailing: Text(
                          '${formatter.format(record.value)} $currency',
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    color: record.value < 0
                                        ? colorScheme.error
                                        : colorScheme.onSurface,
                                    fontWeight: FontWeight.bold,
                                  ),
                        ),
                      ),
                    ),
            ],
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
