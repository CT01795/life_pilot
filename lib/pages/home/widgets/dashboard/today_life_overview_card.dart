import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/pages/home/model/dashboard/model_dashboard.dart';
import 'package:life_pilot/pages/home/model/dashboard/model_schedule_overview.dart';
import 'package:life_pilot/pages/home/model/dashboard/model_schedule_timing.dart';
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
    this.showPoints = true,
  });

  final VoidCallback onSchedulePressed;
  final VoidCallback onAccountingPressed;
  final VoidCallback onPointsPressed;
  final VoidCallback onAccountingQuickAdd;
  final VoidCallback onPointsQuickAdd;
  final VoidCallback onDiscoverEvents;
  final VoidCallback onDiscoverPlaces;
  final bool showPoints;

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final todayEvents = context.select<ModelDashboard, List<CalendarEvent>>(
      (model) => model.state.todayEvents,
    );
    final now = DateTime.now();
    final scheduleOverview = ModelScheduleOverview.from(todayEvents, now);
    final eventCount = scheduleOverview.todayCount;
    final nextEvent = scheduleOverview.nextEvent;
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
    final numberFormats = _OverviewNumberFormats.forLocale(loc.localeName);

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
              if (nextEvent != null) ...[
                Gaps.h12,
                Tooltip(
                  message: loc.jumpToScheduleSection,
                  child: Material(
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
                            Icon(
                              Icons.next_plan_outlined,
                              color: colors.primary,
                            ),
                            Gaps.w12,
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    scheduleOverview.nextEventNeedsReview
                                        ? loc.scheduleAwaitingReview
                                        : loc.upcomingSchedule,
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelMedium
                                        ?.copyWith(
                                          color: colors.onSurfaceVariant,
                                        ),
                                  ),
                                  Text(
                                    nextEvent.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleSmall
                                        ?.copyWith(fontWeight: FontWeight.w800),
                                  ),
                                  if (_nextEventTiming(context, nextEvent, now)
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
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
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
                ),
              ] else if (scheduleOverview.nextFreeAt case final freeAt?) ...[
                Gaps.h12,
                _WrappingOverviewAction(
                  icon: Icons.free_breakfast_outlined,
                  label: loc.nextFreeHour(
                    MaterialLocalizations.of(
                      context,
                    ).formatTimeOfDay(TimeOfDay.fromDateTime(freeAt)),
                    MaterialLocalizations.of(context).formatTimeOfDay(
                      TimeOfDay.fromDateTime(
                        freeAt.add(const Duration(hours: 1)),
                      ),
                    ),
                  ),
                  tooltip: loc.jumpToScheduleSection,
                  onPressed: onSchedulePressed,
                ),
              ],
              if (scheduleOverview.todayConflictCount > 0) ...[
                Gaps.h8,
                _ScheduleConflictBanner(
                  message: loc.scheduleConflictToday(
                    scheduleOverview.todayConflictCount,
                  ),
                  tooltip: loc.jumpToScheduleSection,
                  onPressed: onSchedulePressed,
                ),
              ],
              if (scheduleOverview.tomorrowConflictCount > 0) ...[
                Gaps.h8,
                _ScheduleConflictBanner(
                  message: loc.scheduleConflictTomorrow(
                    scheduleOverview.tomorrowConflictCount,
                  ),
                  tooltip: loc.jumpToScheduleSection,
                  onPressed: onSchedulePressed,
                ),
              ],
              Gaps.h8,
              ActionChip(
                avatar: const Icon(Icons.upcoming_outlined, size: 18),
                label: Text(
                  loc.tomorrowScheduleCount(scheduleOverview.tomorrowCount),
                ),
                tooltip: loc.jumpToScheduleSection,
                onPressed: onSchedulePressed,
              ),
              if (scheduleOverview.overdueCount > 0) ...[
                Gaps.h8,
                ActionChip(
                  avatar: Icon(
                    Icons.notification_important_outlined,
                    size: 18,
                    color: colors.error,
                  ),
                  label: Text(
                    loc.scheduleNeedsReviewCount(scheduleOverview.overdueCount),
                  ),
                  tooltip: loc.jumpToScheduleSection,
                  onPressed: onSchedulePressed,
                ),
              ],
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
              Gaps.h12,
              LayoutBuilder(
                builder: (context, constraints) {
                  final tileCount = showPoints ? 3 : 2;
                  final tileWidth =
                      (constraints.maxWidth - (tileCount - 1) * 8) / tileCount;
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
                        tooltip: loc.jumpToScheduleSection,
                        onPressed: onSchedulePressed,
                      ),
                      _OverviewMetric(
                        width: tileWidth,
                        icon: Icons.account_balance_wallet_outlined,
                        label: loc.todayIncomeExpense,
                        value: hasAccountingAccount
                            ? '${numberFormats.decimal.format(accountingTotal)} $currency'
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
                        tooltip: loc.jumpToAccountingSection,
                        onPressed: onAccountingPressed,
                      ),
                      if (showPoints)
                        _OverviewMetric(
                          width: tileWidth,
                          icon: Icons.stars_outlined,
                          label: loc.todayPoints,
                          value: hasPointAccount
                              ? numberFormats.integer.format(pointsTotal)
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
                          tooltip: loc.jumpToPointsSection,
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
                  if (showPoints)
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

  String? _nextEventTiming(
    BuildContext context,
    CalendarEvent event,
    DateTime now,
  ) {
    final timing = ModelScheduleTiming.forEvent(event, now);
    if (timing == null) return null;
    final loc = AppLocalizations.of(context)!;
    return switch (timing.kind) {
      ScheduleTimingKind.needsReview => loc.scheduleNeedsReview,
      ScheduleTimingKind.alreadyStarted => loc.scheduleAlreadyStarted,
      ScheduleTimingKind.minutes => loc.scheduleStartsInMinutes(timing.amount),
      ScheduleTimingKind.hours => loc.scheduleStartsInHours(timing.amount),
    };
  }
}

class _OverviewNumberFormats {
  const _OverviewNumberFormats({required this.decimal, required this.integer});

  factory _OverviewNumberFormats.forLocale(String locale) => _cache.putIfAbsent(
    locale,
    () => _OverviewNumberFormats(
      decimal: NumberFormat('#,##0.##', locale),
      integer: NumberFormat('#,##0', locale),
    ),
  );

  static final Map<String, _OverviewNumberFormats> _cache = {};

  final NumberFormat decimal;
  final NumberFormat integer;
}

class _ScheduleConflictBanner extends StatelessWidget {
  const _ScheduleConflictBanner({
    required this.message,
    required this.tooltip,
    required this.onPressed,
  });

  final String message;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: colors.errorContainer,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            child: Row(
              children: [
                Icon(Icons.event_busy_outlined, color: colors.onErrorContainer),
                Gaps.w8,
                Expanded(
                  child: Text(
                    message,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: colors.onErrorContainer,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Icon(Icons.chevron_right, color: colors.onErrorContainer),
              ],
            ),
          ),
        ),
      ),
    );
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

class _WrappingOverviewAction extends StatelessWidget {
  const _WrappingOverviewAction({
    required this.icon,
    required this.label,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Tooltip(
      message: tooltip,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Material(
          color: colors.secondaryContainer,
          borderRadius: BorderRadius.circular(20),
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 18, color: colors.onSecondaryContainer),
                  Gaps.w8,
                  Flexible(
                    child: Text(
                      label,
                      softWrap: true,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: colors.onSecondaryContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),
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
    required this.statusIcon,
    required this.accentColor,
    required this.isLoading,
    required this.tooltip,
    required this.onPressed,
  });

  final double width;
  final IconData icon;
  final String label;
  final String value;
  final IconData statusIcon;
  final Color accentColor;
  final bool isLoading;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Tooltip(
      message: tooltip,
      child: SizedBox(
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
                            Gaps.w8,
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
      ),
    );
  }
}
