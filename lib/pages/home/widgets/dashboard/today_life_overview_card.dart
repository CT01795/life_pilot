import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/pages/home/model/dashboard/model_dashboard.dart';
import 'package:life_pilot/pages/home/model/event/calendar_event.dart';
import 'package:life_pilot/utils/const.dart';
import 'package:provider/provider.dart';

class TodayLifeOverviewCard extends StatelessWidget {
  const TodayLifeOverviewCard({
    super.key,
    required this.onSchedulePressed,
    required this.onAccountingPressed,
    required this.onPointsPressed,
    required this.onAccountingQuickAdd,
    required this.onPointsQuickAdd,
    required this.onDiscoverEvents,
    required this.onDiscoverPlaces,
  });

  final VoidCallback onSchedulePressed;
  final VoidCallback onAccountingPressed;
  final VoidCallback onPointsPressed;
  final VoidCallback onAccountingQuickAdd;
  final VoidCallback onPointsQuickAdd;
  final VoidCallback onDiscoverEvents;
  final VoidCallback onDiscoverPlaces;

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final todayEvents = context.select<ModelDashboard, List<CalendarEvent>>(
      (model) => model.state.todayEvents,
    );
    final eventCount = todayEvents.length;
    final nextEvent = todayEvents.isEmpty ? null : todayEvents.first;
    final scheduleConflictCount = _countScheduleConflicts(todayEvents);
    final accountingTotal = context.select<ModelDashboard, num>(
      (model) => model.state.todayAccountingTotal,
    );
    final currency = context.select<ModelDashboard, String>(
      (model) => model.state.accountingCurrency,
    );
    final pointsTotal = context.select<ModelDashboard, int>(
      (model) => model.state.todayPointsTotal,
    );
    final hasAccountingAccount = context.select<ModelDashboard, bool>(
      (model) => model.setting.accountingAccountId != null,
    );
    final hasPointAccount = context.select<ModelDashboard, bool>(
      (model) => model.setting.pointAccountId != null,
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
                eventCount == 0
                    ? loc.homeInsightDiscover
                    : !hasAccountingAccount || !hasPointAccount
                    ? loc.homeInsightConnectAccounts
                    : loc.homeInsightReadyForReview,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colors.onPrimaryContainer.withValues(alpha: 0.82),
                ),
              ),
              if (eventCount == 0) ...[
                Gaps.h12,
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _OverviewAction(
                      icon: Icons.celebration_outlined,
                      label: loc.findRecommendedEvent,
                      onPressed: onDiscoverEvents,
                    ),
                    _OverviewAction(
                      icon: Icons.attractions_outlined,
                      label: loc.findRecommendedPlace,
                      onPressed: onDiscoverPlaces,
                    ),
                  ],
                ),
              ],
              if (nextEvent != null) ...[
                Gaps.h12,
                Material(
                  color: colors.surface.withValues(alpha: 0.68),
                  borderRadius: BorderRadius.circular(16),
                  child: InkWell(
                    onTap: onSchedulePressed,
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.next_plan_outlined, color: colors.primary),
                          Gaps.w12,
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  loc.upcomingSchedule,
                                  style: Theme.of(context).textTheme.labelMedium
                                      ?.copyWith(
                                        color: colors.onSurfaceVariant,
                                      ),
                                ),
                                Text(
                                  nextEvent.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.titleSmall
                                      ?.copyWith(fontWeight: FontWeight.w800),
                                ),
                                if (_nextEventTiming(context, nextEvent)
                                    case final timing?)
                                  Text(
                                    timing,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelLarge
                                        ?.copyWith(
                                          color: colors.primary,
                                          fontWeight: FontWeight.w800,
                                        ),
                                  ),
                                if (_nextEventDetails(context, nextEvent)
                                    case final details?)
                                  Text(
                                    details,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(
                                          color: colors.onSurfaceVariant,
                                        ),
                                  ),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
              if (scheduleConflictCount > 0) ...[
                Gaps.h8,
                Material(
                  color: colors.errorContainer,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    onTap: onSchedulePressed,
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 9,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.event_busy_outlined,
                            color: colors.onErrorContainer,
                          ),
                          Gaps.w8,
                          Expanded(
                            child: Text(
                              loc.scheduleConflictCount(scheduleConflictCount),
                              style: Theme.of(context).textTheme.labelLarge
                                  ?.copyWith(
                                    color: colors.onErrorContainer,
                                    fontWeight: FontWeight.w800,
                                  ),
                            ),
                          ),
                          Icon(
                            Icons.chevron_right,
                            color: colors.onErrorContainer,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
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
                        statusIcon: eventCount > 0
                            ? Icons.event_available_outlined
                            : Icons.event_busy_outlined,
                        accentColor: colors.primary,
                        isLoading: scheduleLoading,
                        onPressed: onSchedulePressed,
                      ),
                      _OverviewMetric(
                        width: tileWidth,
                        icon: Icons.account_balance_wallet_outlined,
                        label: loc.todayIncomeExpense,
                        value: hasAccountingAccount
                            ? '${numberFormat.format(accountingTotal)} $currency'
                            : loc.selectAccount,
                        statusIcon: !hasAccountingAccount
                            ? Icons.info_outline
                            : accountingTotal > 0
                            ? Icons.trending_up
                            : accountingTotal < 0
                            ? Icons.trending_down
                            : Icons.trending_flat,
                        accentColor: !hasAccountingAccount
                            ? colors.secondary
                            : accountingTotal < 0
                            ? colors.error
                            : colors.tertiary,
                        isLoading: accountingLoading,
                        onPressed: onAccountingPressed,
                      ),
                      _OverviewMetric(
                        width: tileWidth,
                        icon: Icons.stars_outlined,
                        label: loc.todayPoints,
                        value: hasPointAccount
                            ? NumberFormat('#,##0').format(pointsTotal)
                            : loc.selectAccount,
                        statusIcon: !hasPointAccount
                            ? Icons.info_outline
                            : pointsTotal > 0
                            ? Icons.trending_up
                            : pointsTotal < 0
                            ? Icons.trending_down
                            : Icons.trending_flat,
                        accentColor: !hasPointAccount
                            ? colors.secondary
                            : pointsTotal < 0
                            ? colors.error
                            : colors.tertiary,
                        isLoading: pointsLoading,
                        onPressed: onPointsPressed,
                      ),
                    ],
                  );
                },
              ),
              Gaps.h12,
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _OverviewAction(
                    icon: Icons.add_card_outlined,
                    label: loc.quickAddAccounting,
                    onPressed: onAccountingQuickAdd,
                  ),
                  _OverviewAction(
                    icon: Icons.add_circle_outline,
                    label: loc.quickAddPoints,
                    onPressed: onPointsQuickAdd,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String? _nextEventDetails(BuildContext context, CalendarEvent event) {
    final values = <String>[
      if (event.startTime != null)
        MaterialLocalizations.of(context).formatTimeOfDay(event.startTime!),
      if (event.location?.trim().isNotEmpty == true) event.location!.trim(),
    ];
    return values.isEmpty ? null : values.join(' · ');
  }

  String? _nextEventTiming(BuildContext context, CalendarEvent event) {
    final startDate = event.startDate;
    final startTime = event.startTime;
    if (startDate == null || startTime == null) return null;
    final loc = AppLocalizations.of(context)!;
    final now = DateTime.now();
    final startsAt = DateTime(
      startDate.year,
      startDate.month,
      startDate.day,
      startTime.hour,
      startTime.minute,
    );
    final minutes = startsAt.difference(now).inMinutes;
    if (minutes < 0) return loc.scheduleAlreadyStarted;
    if (minutes < 60) return loc.scheduleStartsInMinutes(minutes + 1);
    if (minutes < 24 * 60) {
      return loc.scheduleStartsInHours((minutes / 60).ceil());
    }
    return null;
  }

  int _countScheduleConflicts(List<CalendarEvent> events) {
    final today = DateUtils.dateOnly(DateTime.now());
    final tomorrow = today.add(const Duration(days: 1));
    final intervals = <({DateTime start, DateTime end})>[];
    for (final event in events) {
      if (event.isCompleted) continue;
      final startDate = event.startDate;
      final startTime = event.startTime;
      if (startDate == null || startTime == null) continue;
      if (!DateUtils.isSameDay(startDate, today) &&
          !DateUtils.isSameDay(startDate, tomorrow)) {
        continue;
      }
      final endDate = event.endDate ?? startDate;
      final start = DateTime(
        startDate.year,
        startDate.month,
        startDate.day,
        startTime.hour,
        startTime.minute,
      );
      final endTime = event.endTime;
      final end = endTime != null
          ? DateTime(
              endDate.year,
              endDate.month,
              endDate.day,
              endTime.hour,
              endTime.minute,
            )
          : DateUtils.dateOnly(endDate).isAfter(DateUtils.dateOnly(startDate))
          ? DateUtils.dateOnly(endDate).add(const Duration(days: 1))
          : start.add(const Duration(hours: 1));
      if (end.isAfter(start)) intervals.add((start: start, end: end));
    }
    intervals.sort((a, b) => a.start.compareTo(b.start));
    var conflicts = 0;
    for (var i = 0; i < intervals.length; i++) {
      for (var j = i + 1; j < intervals.length; j++) {
        if (!intervals[j].start.isBefore(intervals[i].end)) break;
        conflicts++;
      }
    }
    return conflicts;
  }
}

class _OverviewAction extends StatelessWidget {
  const _OverviewAction({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: Icon(icon, size: 18),
      label: Text(label),
      onPressed: onPressed,
      tooltip: label,
    );
  }
}

class _OverviewMetric extends StatelessWidget {
  const _OverviewMetric({
    required this.width,
    required this.icon,
    required this.label,
    required this.value,
    required this.statusIcon,
    required this.accentColor,
    required this.isLoading,
    required this.onPressed,
  });

  final double width;
  final IconData icon;
  final String label;
  final String value;
  final IconData statusIcon;
  final Color accentColor;
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
                Icon(icon, color: accentColor),
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
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(statusIcon, size: 16, color: accentColor),
                          const SizedBox(width: 4),
                          Text(
                            value,
                            maxLines: 1,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  color: accentColor,
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                        ],
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
