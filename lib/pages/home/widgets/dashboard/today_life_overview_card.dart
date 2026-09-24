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
    final scheduleOverview = _ScheduleOverview.from(
      todayEvents,
      DateTime.now(),
    );
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
              if (scheduleOverview.overdueCount > 0 ||
                  scheduleOverview.tomorrowCount > 0 ||
                  scheduleOverview.nextFreeAt != null) ...[
                Gaps.h8,
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (scheduleOverview.overdueCount > 0)
                      ActionChip(
                        avatar: Icon(
                          Icons.notification_important_outlined,
                          size: 18,
                          color: colors.error,
                        ),
                        label: Text(
                          loc.scheduleNeedsReviewCount(
                            scheduleOverview.overdueCount,
                          ),
                        ),
                        onPressed: onSchedulePressed,
                      ),
                    if (scheduleOverview.tomorrowCount > 0)
                      ActionChip(
                        avatar: const Icon(Icons.upcoming_outlined, size: 18),
                        label: Text(
                          loc.tomorrowScheduleCount(
                            scheduleOverview.tomorrowCount,
                          ),
                        ),
                        onPressed: onSchedulePressed,
                      ),
                    if (scheduleOverview.nextFreeAt case final freeAt?)
                      ActionChip(
                        avatar: const Icon(Icons.free_breakfast_outlined),
                        label: Text(
                          loc.nextFreeHour(
                            MaterialLocalizations.of(
                              context,
                            ).formatTimeOfDay(TimeOfDay.fromDateTime(freeAt)),
                            MaterialLocalizations.of(context).formatTimeOfDay(
                              TimeOfDay.fromDateTime(
                                freeAt.add(const Duration(hours: 1)),
                              ),
                            ),
                          ),
                        ),
                        onPressed: onSchedulePressed,
                      ),
                  ],
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
                                  scheduleOverview.nextEventNeedsReview
                                      ? loc.scheduleAwaitingReview
                                      : loc.upcomingSchedule,
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
              if (scheduleOverview.todayConflictCount > 0) ...[
                Gaps.h8,
                _ScheduleConflictBanner(
                  message: loc.scheduleConflictToday(
                    scheduleOverview.todayConflictCount,
                  ),
                  onPressed: onSchedulePressed,
                ),
              ],
              if (scheduleOverview.tomorrowConflictCount > 0) ...[
                Gaps.h8,
                _ScheduleConflictBanner(
                  message: loc.scheduleConflictTomorrow(
                    scheduleOverview.tomorrowConflictCount,
                  ),
                  onPressed: onSchedulePressed,
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
    if (minutes < 0) {
      final endDate = event.endDate ?? startDate;
      final endTime = event.endTime;
      final endsAt = endTime != null
          ? DateTime(
              endDate.year,
              endDate.month,
              endDate.day,
              endTime.hour,
              endTime.minute,
            )
          : startsAt.add(const Duration(hours: 1));
      return !endsAt.isAfter(now)
          ? loc.scheduleNeedsReview
          : loc.scheduleAlreadyStarted;
    }
    if (minutes < 60) return loc.scheduleStartsInMinutes(minutes + 1);
    if (minutes < 24 * 60) {
      return loc.scheduleStartsInHours((minutes / 60).ceil());
    }
    return null;
  }
}

class _ScheduleOverview {
  const _ScheduleOverview({
    required this.todayCount,
    required this.tomorrowCount,
    required this.overdueCount,
    required this.todayConflictCount,
    required this.tomorrowConflictCount,
    required this.nextEvent,
    required this.nextEventNeedsReview,
    required this.nextFreeAt,
  });

  factory _ScheduleOverview.from(List<CalendarEvent> events, DateTime now) {
    final minuteKey = now.millisecondsSinceEpoch ~/ 60000;
    final cached = _cache[events];
    if (cached != null &&
        cached.minuteKey == minuteKey &&
        cached.eventCount == events.length) {
      return cached.overview;
    }

    final overview = _ScheduleOverview._build(events, now);
    _cache[events] = _ScheduleOverviewCache(
      minuteKey: minuteKey,
      eventCount: events.length,
      overview: overview,
    );
    return overview;
  }

  factory _ScheduleOverview._build(List<CalendarEvent> events, DateTime now) {
    final today = DateUtils.dateOnly(now);
    final tomorrow = today.add(const Duration(days: 1));
    final activeEvents =
        events
            .where((event) => !event.isCompleted && event.startDate != null)
            .toList(growable: false)
          ..sort((a, b) => _eventStart(a).compareTo(_eventStart(b)));
    final todayEvents = activeEvents
        .where((event) => DateUtils.isSameDay(event.startDate, today))
        .toList(growable: false);
    final tomorrowEvents = activeEvents
        .where((event) => DateUtils.isSameDay(event.startDate, tomorrow))
        .toList(growable: false);
    final overdueCount = todayEvents
        .where((event) => _hasEnded(event, now))
        .length;
    final nextEvent = activeEvents.firstOrNull;

    return _ScheduleOverview(
      todayCount: todayEvents.length,
      tomorrowCount: tomorrowEvents.length,
      overdueCount: overdueCount,
      todayConflictCount: _countConflicts(todayEvents),
      tomorrowConflictCount: _countConflicts(tomorrowEvents),
      nextEvent: nextEvent,
      nextEventNeedsReview: nextEvent != null && _hasEnded(nextEvent, now),
      nextFreeAt: _findNextFreeHour(todayEvents, now),
    );
  }

  static final Expando<_ScheduleOverviewCache> _cache =
      Expando<_ScheduleOverviewCache>('scheduleOverview');

  final int todayCount;
  final int tomorrowCount;
  final int overdueCount;
  final int todayConflictCount;
  final int tomorrowConflictCount;
  final CalendarEvent? nextEvent;
  final bool nextEventNeedsReview;
  final DateTime? nextFreeAt;

  static DateTime? _findNextFreeHour(List<CalendarEvent> events, DateTime now) {
    final today = DateUtils.dateOnly(now);
    final dayStart = DateTime(today.year, today.month, today.day, 8);
    final dayEnd = DateTime(today.year, today.month, today.day, 22);
    if (!now.isBefore(dayEnd)) return null;
    var cursor = now.isAfter(dayStart) ? now : dayStart;
    if (cursor.minute % 15 != 0 || cursor.second != 0) {
      cursor = DateTime(
        cursor.year,
        cursor.month,
        cursor.day,
        cursor.hour,
        ((cursor.minute ~/ 15) + 1) * 15,
      );
    }
    final intervals =
        events
            .map(_interval)
            .whereType<({DateTime start, DateTime end})>()
            .toList(growable: false)
          ..sort((a, b) => a.start.compareTo(b.start));
    for (final interval in intervals) {
      if (!interval.end.isAfter(cursor)) continue;
      if (interval.start.difference(cursor) >= const Duration(hours: 1)) {
        return cursor;
      }
      if (interval.end.isAfter(cursor)) cursor = interval.end;
    }
    return dayEnd.difference(cursor) >= const Duration(hours: 1)
        ? cursor
        : null;
  }

  static int _countConflicts(List<CalendarEvent> events) {
    final intervals = events
        .map(_interval)
        .whereType<({DateTime start, DateTime end})>()
        .toList(growable: false);
    intervals.sort((a, b) => a.start.compareTo(b.start));
    if (intervals.length < 2) return 0;
    final affected = <int>{};
    var furthestEnd = intervals.first.end;
    var furthestEndIndex = 0;
    for (var i = 1; i < intervals.length; i++) {
      final interval = intervals[i];
      if (interval.start.isBefore(furthestEnd)) {
        affected
          ..add(furthestEndIndex)
          ..add(i);
      } else {
        furthestEnd = interval.end;
        furthestEndIndex = i;
        continue;
      }
      if (interval.end.isAfter(furthestEnd)) {
        furthestEnd = interval.end;
        furthestEndIndex = i;
      }
    }
    return affected.length;
  }

  static DateTime _eventStart(CalendarEvent event) {
    final date = event.startDate!;
    final time = event.startTime;
    return DateTime(
      date.year,
      date.month,
      date.day,
      time?.hour ?? 0,
      time?.minute ?? 0,
    );
  }

  static bool _hasEnded(CalendarEvent event, DateTime now) {
    final interval = _interval(event);
    return interval != null && !interval.end.isAfter(now);
  }

  static ({DateTime start, DateTime end})? _interval(CalendarEvent event) {
    final startDate = event.startDate;
    final startTime = event.startTime;
    if (startDate == null || startTime == null) return null;
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
    return end.isAfter(start) ? (start: start, end: end) : null;
  }
}

class _ScheduleOverviewCache {
  const _ScheduleOverviewCache({
    required this.minuteKey,
    required this.eventCount,
    required this.overview,
  });

  final int minuteKey;
  final int eventCount;
  final _ScheduleOverview overview;
}

class _ScheduleConflictBanner extends StatelessWidget {
  const _ScheduleConflictBanner({
    required this.message,
    required this.onPressed,
  });

  final String message;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
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
