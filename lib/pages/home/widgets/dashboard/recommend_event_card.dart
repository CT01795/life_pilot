import 'package:flutter/material.dart';
import 'package:life_pilot/apps/controller_page_main.dart';
import 'package:life_pilot/auth/model_auth_view.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/pages/home/model/event/recommended_event.dart';
import 'package:life_pilot/pages/home/model/dashboard/model_dashboard.dart';
import 'package:life_pilot/pages/home/service/calendar_service.dart';
import 'package:life_pilot/pages/home/service/event_tracking_service.dart';
import 'package:life_pilot/pages/home/widgets/dashboard/event_city_selector_button.dart';
import 'package:life_pilot/pages/home/widgets/dashboard/dashboard_card_header.dart';
import 'package:life_pilot/pages/home/widgets/dashboard/async_action_checkbox.dart';
import 'package:life_pilot/pages/home/widgets/dashboard/dashboard_load_failure.dart';
import 'package:life_pilot/pages/home/widgets/dashboard/dashboard_header_summary.dart';
import 'package:life_pilot/pages/home/widgets/dashboard/dashboard_section_loading.dart';
import 'package:life_pilot/pages/home/widgets/dashboard/recommendation_highlights.dart';
import 'package:life_pilot/pages/home/widgets/dashboard/recommendation_calendar_actions.dart';
import 'package:life_pilot/utils/const.dart';
import 'package:life_pilot/utils/enum.dart';
import 'package:life_pilot/utils/extension.dart';
import 'package:provider/provider.dart';

class RecommendEventCard extends StatelessWidget {
  final bool isExpanded;
  final bool hasRequestedData;
  final ValueChanged<bool> onExpansionChanged;

  const RecommendEventCard({
    super.key,
    required this.isExpanded,
    required this.hasRequestedData,
    required this.onExpansionChanged,
  });

  Future<void> _addToCalendar({
    required BuildContext context,
    required RecommendedEvent event,
    required String account,
    required AppLocalizations loc,
  }) async {
    final calendar = context.read<CalendarService>();
    final tracking = context.read<EventTrackingService>();
    try {
      final isDuplicate = await calendar.existsRecommendedEventToCal(
        account: account,
        event: event,
      );
      if (!context.mounted) return;
      final schedule = await chooseRecommendationSchedule(
        context: context,
        title: event.name,
        sourceDate: event.startDate,
        sourceTime: event.startTime,
        description: isDuplicate ? loc.scheduleDuplicateConfirmation : null,
      );
      if (schedule == null) return;

      final addedEvent = await calendar.addRecommendedEventToCal(
        account: account,
        event: event,
        id: isDuplicate ? null : event.id,
        scheduledDate: schedule.date,
        scheduledTime: schedule.time,
      );
      if (!context.mounted) return;
      publishAddedCalendarEvent(
        context: context,
        event: addedEvent,
        account: account,
        loc: loc,
      );
      await tracking.incrementEventCounter(
        eventId: event.id,
        eventName: event.name,
        column: 'saves',
      );
    } catch (error, stackTrace) {
      showRecommendationCalendarAddFailure(
        context: context,
        loc: loc,
        error: error,
        stackTrace: stackTrace,
        source: 'recommended event',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final account = context.select<ModelAuthView, String?>(
      (auth) => auth.account,
    );
    final tracking = context.read<EventTrackingService>();
    final today = DateUtils.dateOnly(DateTime.now());
    final events = context.select<ModelDashboard, List<RecommendedEvent>>(
      (m) => m.state.recommendEvents,
    );
    final hasLoadFailed = context.select<ModelDashboard, bool>(
      (m) => m.hasFailed(DashboardSection.recommendEvents),
    );
    final isLoading = context.select<ModelDashboard, bool>(
      (m) => m.isLoading(DashboardSection.recommendEvents),
    );

    return Card(
      color: colorScheme.brightness == Brightness.dark
          ? colorScheme.surfaceContainerHigh
          : const Color(0xFFF1E1CF),
      child: Padding(
        padding: Insets.all12,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DashboardCardHeader(
              icon: Icons.local_activity,
              title: loc.recommendEvent,
              trailingWidth: isExpanded ? 208 : null,
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isExpanded)
                    const Expanded(child: EventCitySelectorButton()),
                  if (!isExpanded)
                    DashboardHeaderSummary(
                      value: hasRequestedData ? events.length.toString() : '—',
                      tooltip: loc.recommendEvent,
                      isLoading:
                          hasRequestedData && isLoading && events.isEmpty,
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
              Gaps.h16,
              if (isLoading && events.isNotEmpty)
                const LinearProgressIndicator(),
              if (hasLoadFailed)
                DashboardLoadFailure(
                  onRetry: () => context.read<ModelDashboard>().retrySection(
                    section: DashboardSection.recommendEvents,
                    account: account!,
                  ),
                )
              else if (isLoading && events.isEmpty)
                const DashboardSectionLoading()
              else if (events.isEmpty)
                ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: Text(loc.noInfoAvailable),
                )
              else
                ...events
                    .take(5)
                    .map(
                      (e) => RepaintBoundary(
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 4,
                          ),
                          leading: Tooltip(
                            message: loc.addToSchedule,
                            child: Transform.scale(
                              scale: 1.5, // 放大倍率
                              child: AsyncActionCheckbox(
                                onAccepted: () => _addToCalendar(
                                  context: context,
                                  event: e,
                                  account: account!,
                                  loc: loc,
                                ),
                              ),
                            ),
                          ),
                          title: Tooltip(
                            message: e.masterUrl?.isNotEmpty == true
                                ? loc.clickHereToSeeMore
                                : '',
                            child: InkWell(
                              onTap:
                                  (e.masterUrl == null || e.masterUrl!.isEmpty)
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
                                '${(e.startDate!.isBefore(today) ? '～ ${e.endDate?.formatDateString()}' : e.startDate?.formatDateString())}\n${e.name}',
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
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              RecommendationHighlights(
                                isFree: e.isFree,
                                type: e.type,
                                city: e.city,
                                detail: _recommendedEventTimeRange(e),
                              ),
                              Tooltip(
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
                                      if ((e.city != null &&
                                              e.city!.isNotEmpty) ||
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
                            ],
                          ),
                        ),
                      ),
                    ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {
                    context.read<ControllerPageMain>().changePage(
                      PageType.recommendEvent,
                    );
                  },
                  child: Text(
                    events.length > 5
                        ? loc.viewRemainingRecommendations(events.length - 5)
                        : loc.clickHereToSeeMore,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

String? _recommendedEventTimeRange(RecommendedEvent event) {
  final start = event.startTime?.formatTimeString();
  final end = event.endTime?.formatTimeString();
  if (start == null || start.isEmpty) return null;
  return end == null || end.isEmpty ? start : '$start–$end';
}
