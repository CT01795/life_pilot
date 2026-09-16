import 'package:flutter/material.dart';
import 'package:life_pilot/accounting/service_accounting.dart';
import 'package:life_pilot/subscription/widgets_subscription_usage.dart';
import 'package:life_pilot/apps/controller_page_main.dart';
import 'package:life_pilot/auth/controller_auth.dart';
import 'package:life_pilot/auth/model_auth_view.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/pages/home/model/event/calendar_event.dart';
import 'package:life_pilot/pages/home/model/dashboard/model_dashboard.dart';
import 'package:life_pilot/pages/home/service/calendar_service.dart';
import 'package:life_pilot/pages/home/service/event_tracking_service.dart';
import 'package:life_pilot/pages/home/widgets/dashboard/async_action_checkbox.dart';
import 'package:life_pilot/pages/home/widgets/dashboard/dashboard_load_failure.dart';
import 'package:life_pilot/pages/home/widgets/dashboard/dashboard_section_loading.dart';
import 'package:life_pilot/pages/home/widgets/dashboard/dashboard_card_header.dart';
import 'package:life_pilot/pages/home/widgets/dashboard/dashboard_header_summary.dart';
import 'package:life_pilot/pages/home/widgets/dashboard/event_completion_sheet.dart';
import 'package:life_pilot/pages/home/widgets/dashboard/event_completion_accounting.dart';
import 'package:life_pilot/point_record/model_point_record_preview.dart';
import 'package:life_pilot/point_record/service_point_record.dart';
import 'package:life_pilot/utils/const.dart';
import 'package:life_pilot/utils/enum.dart';
import 'package:life_pilot/utils/extension.dart';
import 'package:life_pilot/calendar/controller_notification.dart';
import 'package:provider/provider.dart';

import '../../../../utils/logger.dart';

class TodayScheduleCard extends StatelessWidget {
  final bool isExpanded;
  final ValueChanged<bool> onExpansionChanged;

  const TodayScheduleCard({
    super.key,
    required this.isExpanded,
    required this.onExpansionChanged,
  });

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final account = context.select<ModelAuthView, String?>(
      (auth) => auth.account,
    );
    final tracking = context.read<EventTrackingService>();
    final events = context.select<ModelDashboard, List<CalendarEvent>>(
      (m) => m.state.todayEvents,
    );
    final hasLoadFailed = context.select<ModelDashboard, bool>(
      (m) => m.hasFailed(DashboardSection.todaySchedule),
    );
    final isLoading = context.select<ModelDashboard, bool>(
      (m) => m.isLoading(DashboardSection.todaySchedule),
    );
    final accountingAccountId = context.select<ModelDashboard, String?>(
      (m) => m.setting.accountingAccountId,
    );
    final accountingAccountName = context.select<ModelDashboard, String?>(
      (m) => m.setting.accountingAccountName,
    );
    final accountingCurrency = context.select<ModelDashboard, String>(
      (m) => m.state.accountingCurrency,
    );
    final pointAccountId = context.select<ModelDashboard, String?>(
      (m) => m.setting.pointAccountId,
    );
    final pointAccountName = context.select<ModelDashboard, String?>(
      (m) => m.setting.pointAccountName,
    );

    return Card(
      color: colorScheme.brightness == Brightness.dark
          ? colorScheme.surfaceContainerHigh
          : const Color(0xFFD6E4F0),
      child: Padding(
        padding: Insets.all12,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DashboardCardHeader(
              icon: Icons.calendar_today,
              title: loc.upcomingSchedule,
              trailingWidth: null,
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!isExpanded)
                    DashboardHeaderSummary(
                      value: events.length.toString(),
                      tooltip: loc.upcomingSchedule,
                      isLoading: isLoading && events.isEmpty,
                    ),
                  IconButton(
                    onPressed: () => onExpansionChanged(!isExpanded),
                    icon: AnimatedRotation(
                      turns: isExpanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 180),
                      child: const Icon(Icons.keyboard_arrow_down),
                    ),
                  ),
                ],
              ),
            ),
            if (isExpanded) ...[
              if (events.isNotEmpty) ...[
                Gaps.h8,
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.auto_awesome_outlined,
                      size: 18,
                      color: colorScheme.primary,
                    ),
                    Gaps.w8,
                    Expanded(
                      child: Text(
                        loc.homeJourneyReviewHint,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              Gaps.h16,
              if (isLoading && events.isNotEmpty)
                const LinearProgressIndicator(),
              if (hasLoadFailed)
                DashboardLoadFailure(
                  onRetry: () => context.read<ModelDashboard>().retrySection(
                    section: DashboardSection.todaySchedule,
                    account: account!,
                  ),
                )
              else if (isLoading && events.isEmpty)
                const DashboardSectionLoading()
              else if (events.isEmpty)
                ListTile(
                  leading: Icon(Icons.info_outline),
                  title: Text(loc.noInfoAvailable),
                )
              else
                ...events
                    .take(5)
                    .map(
                      (e) => ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 4,
                        ),
                        leading: Tooltip(
                          message: loc.completeAndReview,
                          child: Transform.scale(
                            scale: 1.5, // 放大倍率
                            child: AsyncActionCheckbox(
                              onAccepted: () async {
                                final choice = await showEventCompletionSheet(
                                  context,
                                  eventName: e.name,
                                  accountingAccountName: accountingAccountName,
                                  accountingCurrency: accountingCurrency,
                                  pointAccountName: pointAccountName,
                                );
                                if (choice == null || !context.mounted) {
                                  return;
                                }
                                try {
                                  await context
                                      .read<ModelDashboard>()
                                      .completeEvent(
                                        id: e.id,
                                        account: account!,
                                      );
                                  await context
                                      .read<ControllerNotification>()
                                      .cancelAllEventReminders(eventId: e.id);
                                } catch (error, stackTrace) {
                                  logger.e(
                                    'Could not complete today schedule event.',
                                    error: error,
                                    stackTrace: stackTrace,
                                  );
                                  if (context.mounted) {
                                    final message = subscriptionErrorMessage(
                                      loc,
                                      error,
                                    );
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          message.isNotEmpty
                                              ? message
                                              : loc.eventSaveFailed,
                                        ),
                                      ),
                                    );
                                  }
                                  return;
                                }
                                final pendingWrites = <Future<void>>[];
                                var memorySaved = false;
                                var accountingSaved = false;
                                var pointsSaved = false;
                                if (choice.addToMemory) {
                                  final calendar = context
                                      .read<CalendarService>();
                                  pendingWrites.add(() async {
                                    try {
                                      await calendar.addCalendarEventToMemory(
                                        account: account,
                                        event: e,
                                        id: e.id,
                                      );
                                      memorySaved = true;
                                    } catch (error, stackTrace) {
                                      logger.e(
                                        'Could not add calendar event to memory.',
                                        error: error,
                                        stackTrace: stackTrace,
                                      );
                                      if (context.mounted) {
                                        final message =
                                            subscriptionErrorMessage(
                                              loc,
                                              error,
                                            );
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              message.isNotEmpty
                                                  ? message
                                                  : loc.eventSaveFailed,
                                            ),
                                          ),
                                        );
                                      }
                                    }
                                  }());
                                }
                                final accountingRecords =
                                    buildEventAccountingRecords(
                                      eventName: e.name,
                                      eventId: e.id,
                                      currency: accountingCurrency,
                                      recordedAt: choice.recordedAt,
                                      incomeValue: choice.incomeValue,
                                      incomeCategory: choice.incomeCategory,
                                      expenseValue: choice.expenseValue,
                                      expenseCategory: choice.expenseCategory,
                                    );
                                if (accountingRecords.isNotEmpty) {
                                  pendingWrites.add(() async {
                                    try {
                                      await ServiceAccounting()
                                          .insertRecordsBatch(
                                            accountId: accountingAccountId!,
                                            type: 'balance',
                                            records: accountingRecords,
                                            currency: accountingCurrency,
                                          );
                                      accountingSaved = true;
                                    } catch (error, stackTrace) {
                                      logger.e(
                                        'Could not add event accounting records.',
                                        error: error,
                                        stackTrace: stackTrace,
                                      );
                                      if (context.mounted) {
                                        final message =
                                            subscriptionErrorMessage(
                                              loc,
                                              error,
                                            );
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              message.isNotEmpty
                                                  ? message
                                                  : loc.eventSaveFailed,
                                            ),
                                          ),
                                        );
                                      }
                                    }
                                  }());
                                }
                                if (choice.pointValue case final value?) {
                                  pendingWrites.add(() async {
                                    try {
                                      await ServicePointRecord()
                                          .insertRecordsBatch(
                                            accountId: pointAccountId!,
                                            type: 'points',
                                            records: [
                                              PointRecordPreview(
                                                description: e.name,
                                                value: value,
                                                date: choice.recordedAt,
                                                primaryCategory:
                                                    choice.pointCategory,
                                              ),
                                            ],
                                          );
                                      pointsSaved = true;
                                    } catch (error, stackTrace) {
                                      logger.e(
                                        'Could not add event point record.',
                                        error: error,
                                        stackTrace: stackTrace,
                                      );
                                      if (context.mounted) {
                                        final message =
                                            subscriptionErrorMessage(
                                              loc,
                                              error,
                                            );
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              message.isNotEmpty
                                                  ? message
                                                  : loc.eventSaveFailed,
                                            ),
                                          ),
                                        );
                                      }
                                    }
                                  }());
                                }
                                await Future.wait(pendingWrites);
                                if (!context.mounted) {
                                  return;
                                }
                                if (pendingWrites.isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(loc.eventCompleted)),
                                  );
                                  return;
                                }
                                final refreshes = <Future<void>>[
                                  context
                                      .read<ControllerAuth>()
                                      .refreshSubscriptionUsage(),
                                  if (accountingRecords.isNotEmpty)
                                    context
                                        .read<ModelDashboard>()
                                        .refreshAccounting(
                                          accountId: accountingAccountId!,
                                        ),
                                  if (choice.pointValue != null)
                                    context
                                        .read<ModelDashboard>()
                                        .refreshPoints(
                                          accountId: pointAccountId!,
                                        ),
                                ];
                                await Future.wait(refreshes);
                                if (!context.mounted) {
                                  return;
                                }
                                final savedItems = <String>[
                                  if (memorySaved) loc.eventMemory,
                                  if (accountingSaved &&
                                      choice.incomeValue != null)
                                    loc.eventIncome,
                                  if (accountingSaved &&
                                      choice.expenseValue != null)
                                    loc.eventExpense,
                                  if (pointsSaved) loc.pointsRecord,
                                ];
                                final message = savedItems.isEmpty
                                    ? loc.eventCompleted
                                    : loc.eventCompletedWithRecords(
                                        savedItems.join(' · '),
                                      );
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(message)),
                                );
                              },
                            ),
                          ),
                        ),
                        title: Tooltip(
                          message: e.masterUrl?.isNotEmpty == true
                              ? loc.clickHereToSeeMore
                              : '',
                          child: InkWell(
                            onTap: (e.masterUrl == null || e.masterUrl!.isEmpty)
                                ? null
                                : () async {
                                    await tracking.incrementEventCounter(
                                      eventId: e.id,
                                      eventName: e.name,
                                      column: 'page_views',
                                    );
                                    if (!await tracking.launchUrlLink(
                                          e.masterUrl,
                                        ) &&
                                        context.mounted) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            loc.externalLinkOpenFailed,
                                          ),
                                        ),
                                      );
                                    }
                                  },
                            child: Text(
                              '${e.startDate?.formatDateString() == DateTime.now().formatDateString() ? '' : e.startDate?.formatDateString()} ${e.startTime?.formatTimeString() ?? ''} ${e.name}',
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color:
                                    (e.masterUrl == null ||
                                        e.masterUrl!.isEmpty)
                                    ? colorScheme.onSurface
                                    : colorScheme.primary,
                              ),
                            ),
                          ),
                        ),
                        subtitle: Tooltip(
                          message:
                              ((e.city != null && e.city!.isNotEmpty) ||
                                  (e.location != null &&
                                      e.location!.isNotEmpty))
                              ? loc.openMap
                              : '',
                          child: InkWell(
                            onTap:
                                ((e.city != null && e.city!.isNotEmpty) ||
                                    (e.location != null &&
                                        e.location!.isNotEmpty))
                                ? () async {
                                    await tracking.incrementEventCounter(
                                      eventId: e.id,
                                      eventName: e.name,
                                      column: 'card_clicks',
                                    );
                                    if (!await tracking.onOpenMap(
                                          e.city,
                                          e.location,
                                        ) &&
                                        context.mounted) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            loc.externalLinkOpenFailed,
                                          ),
                                        ),
                                      );
                                    }
                                  }
                                : null,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if ((e.city != null && e.city!.isNotEmpty) ||
                                    (e.location != null &&
                                        e.location!.isNotEmpty))
                                  const Icon(Icons.location_on),
                                Gaps.w8,
                                Flexible(
                                  child: Text(
                                    '${e.city ?? ''} ${e.location ?? ''}',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {
                    context.read<ControllerPageMain>().changePage(
                      PageType.personalEvent,
                    );
                  },
                  child: Text(loc.clickHereToSeeMore),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
