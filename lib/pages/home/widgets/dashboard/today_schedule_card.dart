import 'package:flutter/material.dart';
import 'package:life_pilot/accounting/model_accounting_preview.dart';
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
import 'package:life_pilot/pages/home/widgets/dashboard/event_completion_sheet.dart';
import 'package:life_pilot/point_record/model_point_record_preview.dart';
import 'package:life_pilot/point_record/service_point_record.dart';
import 'package:life_pilot/utils/const.dart';
import 'package:life_pilot/utils/enum.dart';
import 'package:life_pilot/utils/extension.dart';
import 'package:life_pilot/calendar/controller_notification.dart';
import 'package:provider/provider.dart';

import '../../../../utils/logger.dart';

class TodayScheduleCard extends StatelessWidget {
  const TodayScheduleCard({
    super.key,
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
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.calendar_today),
              Gaps.w8,
              Text(
                loc.upcomingSchedule,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ]),
            Gaps.h16,
            if (isLoading && events.isNotEmpty) const LinearProgressIndicator(),
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
              ...events.take(5).map(
                    (e) => ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                      leading: Tooltip(
                        message: loc.completeEventTitle,
                        child: Transform.scale(
                          scale: 1.5, // 放大倍率
                          child: AsyncActionCheckbox(onAccepted: () async {
                            final choice = await showEventCompletionSheet(
                              context,
                              eventName: e.name,
                              accountingAccountName: accountingAccountName,
                              accountingCurrency: accountingCurrency,
                              pointAccountName: pointAccountName,
                            );
                            if (choice == null || !context.mounted) return;
                            try {
                              await context
                                  .read<ModelDashboard>()
                                  .completeEvent(
                                    id: e.id,
                                    account: account!,
                                  );
                              await context
                                  .read<ControllerNotification>()
                                  .cancelAllEventReminders(
                                    eventId: e.id,
                                  );
                            } catch (error, stackTrace) {
                              logger.e(
                                'Could not complete today schedule event.',
                                error: error,
                                stackTrace: stackTrace,
                              );
                              if (context.mounted) {
                                final message =
                                    subscriptionErrorMessage(loc, error);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(message.isNotEmpty
                                        ? message
                                        : loc.eventSaveFailed),
                                  ),
                                );
                              }
                              return;
                            }
                            if (choice.addToMemory) {
                              final calendar = context.read<CalendarService>();
                              try {
                                await calendar.addCalendarEventToMemory(
                                    account: account, event: e, id: e.id);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(loc.memoryAddOk)),
                                  );
                                }
                              } catch (error, stackTrace) {
                                logger.e(
                                  'Could not add calendar event to memory.',
                                  error: error,
                                  stackTrace: stackTrace,
                                );
                                if (context.mounted) {
                                  final message =
                                      subscriptionErrorMessage(loc, error);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(message.isNotEmpty
                                          ? message
                                          : loc.eventSaveFailed),
                                    ),
                                  );
                                }
                              }
                            }
                            if (choice.expenseValue case final value?) {
                              try {
                                await ServiceAccounting().insertRecordsBatch(
                                  accountId: accountingAccountId!,
                                  type: 'balance',
                                  records: [
                                    AccountingPreview(
                                      description: e.name,
                                      value: value,
                                      currency: accountingCurrency,
                                      exchangeRate: null,
                                      date: DateTime.now(),
                                      primaryCategory: choice.expenseCategory,
                                    ),
                                  ],
                                  currency: accountingCurrency,
                                );
                                if (context.mounted) {
                                  await context
                                      .read<ControllerAuth>()
                                      .refreshSubscriptionUsage();
                                  await context
                                      .read<ModelDashboard>()
                                      .refreshAccounting(
                                        accountId: accountingAccountId,
                                      );
                                }
                              } catch (error, stackTrace) {
                                logger.e(
                                  'Could not add event expense.',
                                  error: error,
                                  stackTrace: stackTrace,
                                );
                                if (context.mounted) {
                                  final message =
                                      subscriptionErrorMessage(loc, error);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(message.isNotEmpty
                                          ? message
                                          : loc.eventSaveFailed),
                                    ),
                                  );
                                }
                              }
                            }
                            if (choice.pointValue case final value?) {
                              try {
                                await ServicePointRecord().insertRecordsBatch(
                                  accountId: pointAccountId!,
                                  type: 'points',
                                  records: [
                                    PointRecordPreview(
                                      description: e.name,
                                      value: value,
                                      date: DateTime.now(),
                                      primaryCategory: choice.pointCategory,
                                    ),
                                  ],
                                );
                                if (context.mounted) {
                                  await context
                                      .read<ControllerAuth>()
                                      .refreshSubscriptionUsage();
                                  await context
                                      .read<ModelDashboard>()
                                      .refreshPoints(accountId: pointAccountId);
                                }
                              } catch (error, stackTrace) {
                                logger.e(
                                  'Could not add event point record.',
                                  error: error,
                                  stackTrace: stackTrace,
                                );
                                if (context.mounted) {
                                  final message =
                                      subscriptionErrorMessage(loc, error);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(message.isNotEmpty
                                          ? message
                                          : loc.eventSaveFailed),
                                    ),
                                  );
                                }
                              }
                            }
                            context
                                .read<ModelDashboard>()
                                .refreshTodaySchedule(account: account);
                          }),
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
                                  if (!await tracking
                                          .launchUrlLink(e.masterUrl) &&
                                      context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                          content:
                                              Text(loc.externalLinkOpenFailed)),
                                    );
                                  }
                                },
                          child: Text(
                            '${e.startDate?.formatDateString() == DateTime.now().formatDateString() ? '' : e.startDate?.formatDateString()} ${e.startTime?.formatTimeString() ?? ''} ${e.name}',
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color:
                                  (e.masterUrl == null || e.masterUrl!.isEmpty)
                                      ? colorScheme.onSurface
                                      : colorScheme.primary,
                            ),
                          ),
                        ),
                      ),
                      subtitle: Tooltip(
                        message: ((e.city != null && e.city!.isNotEmpty) ||
                                (e.location != null && e.location!.isNotEmpty))
                            ? loc.openMap
                            : '',
                        child: InkWell(
                          onTap: ((e.city != null && e.city!.isNotEmpty) ||
                                  (e.location != null &&
                                      e.location!.isNotEmpty))
                              ? () async {
                                  await tracking.incrementEventCounter(
                                    eventId: e.id,
                                    eventName: e.name,
                                    column: 'card_clicks',
                                  );
                                  if (!await tracking.onOpenMap(
                                          e.city, e.location) &&
                                      context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                          content:
                                              Text(loc.externalLinkOpenFailed)),
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
                                const Icon(
                                  Icons.location_on,
                                ),
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
                  context
                      .read<ControllerPageMain>()
                      .changePage(PageType.personalEvent);
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
