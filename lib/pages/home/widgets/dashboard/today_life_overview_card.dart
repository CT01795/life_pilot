import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/pages/home/model/dashboard/model_dashboard.dart';
import 'package:life_pilot/utils/const.dart';
import 'package:provider/provider.dart';

class TodayLifeOverviewCard extends StatelessWidget {
  const TodayLifeOverviewCard({
    super.key,
    required this.onSchedulePressed,
    required this.onAccountingPressed,
    required this.onPointsPressed,
  });

  final VoidCallback onSchedulePressed;
  final VoidCallback onAccountingPressed;
  final VoidCallback onPointsPressed;

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final eventCount = context.select<ModelDashboard, int>(
      (model) => model.state.todayEvents.length,
    );
    final accountingTotal = context.select<ModelDashboard, num>(
      (model) => model.state.todayAccountingTotal,
    );
    final currency = context.select<ModelDashboard, String>(
      (model) => model.state.accountingCurrency,
    );
    final pointsTotal = context.select<ModelDashboard, int>(
      (model) => model.state.todayPointsTotal,
    );
    final scheduleLoading = context.select<ModelDashboard, bool>(
      (model) => model.isLoading(DashboardSection.todaySchedule),
    );
    final accountingLoading = context.select<ModelDashboard, bool>(
      (model) => model.isLoading(DashboardSection.accounting),
    );
    final pointsLoading = context.select<ModelDashboard, bool>(
      (model) => model.isLoading(DashboardSection.points),
    );
    final numberFormat = NumberFormat('#,##0.##');

    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 3,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              colors.primaryContainer,
              colors.tertiaryContainer.withValues(alpha: 0.72),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.auto_awesome, color: colors.onPrimaryContainer),
                  Gaps.w8,
                  Expanded(
                    child: Text(
                      loc.todayLifeOverview,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: colors.onPrimaryContainer,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              Gaps.h4,
              Text(
                loc.todayLifeOverviewHint,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colors.onPrimaryContainer.withValues(alpha: 0.82),
                ),
              ),
              Gaps.h12,
              LayoutBuilder(
                builder: (context, constraints) {
                  final tileWidth = (constraints.maxWidth - 16) / 3;
                  return Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _OverviewMetric(
                        width: tileWidth,
                        icon: Icons.calendar_today_outlined,
                        label: loc.todaySchedule,
                        value: eventCount.toString(),
                        isLoading: scheduleLoading,
                        onPressed: onSchedulePressed,
                      ),
                      _OverviewMetric(
                        width: tileWidth,
                        icon: Icons.account_balance_wallet_outlined,
                        label: loc.todayIncomeExpense,
                        value:
                            '${numberFormat.format(accountingTotal)} $currency',
                        isLoading: accountingLoading,
                        onPressed: onAccountingPressed,
                      ),
                      _OverviewMetric(
                        width: tileWidth,
                        icon: Icons.stars_outlined,
                        label: loc.todayPoints,
                        value: NumberFormat('#,##0').format(pointsTotal),
                        isLoading: pointsLoading,
                        onPressed: onPointsPressed,
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OverviewMetric extends StatelessWidget {
  const _OverviewMetric({
    required this.width,
    required this.icon,
    required this.label,
    required this.value,
    required this.isLoading,
    required this.onPressed,
  });

  final double width;
  final IconData icon;
  final String label;
  final String value;
  final bool isLoading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SizedBox(
      width: width,
      child: Material(
        color: colors.surface.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: colors.primary),
                Gaps.h4,
                Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
                Gaps.h4,
                if (isLoading)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  SizedBox(
                    height: 24,
                    width: double.infinity,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        value,
                        maxLines: 1,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
