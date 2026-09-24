import 'package:flutter/material.dart';
import 'package:life_pilot/apps/controller_page_main.dart';
import 'package:life_pilot/auth/model_auth_view.dart';
import 'package:life_pilot/calendar/controller_calendar.dart';
import 'package:life_pilot/calendar/widgets_schedule_datetime_dialog.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/pages/home/model/dashboard/model_dashboard.dart';
import 'package:life_pilot/pages/home/model/place/recommended_place.dart';
import 'package:life_pilot/pages/home/service/calendar_service.dart';
import 'package:life_pilot/pages/home/service/event_tracking_service.dart';
import 'package:life_pilot/pages/home/widgets/dashboard/async_action_checkbox.dart';
import 'package:life_pilot/pages/home/widgets/dashboard/dashboard_card_header.dart';
import 'package:life_pilot/pages/home/widgets/dashboard/dashboard_header_summary.dart';
import 'package:life_pilot/pages/home/widgets/dashboard/dashboard_load_failure.dart';
import 'package:life_pilot/pages/home/widgets/dashboard/dashboard_section_loading.dart';
import 'package:life_pilot/pages/home/widgets/dashboard/place_selector_button.dart';
import 'package:life_pilot/pages/home/widgets/dashboard/recommendation_highlights.dart';
import 'package:life_pilot/subscription/widgets_subscription_usage.dart';
import 'package:life_pilot/utils/const.dart';
import 'package:life_pilot/utils/enum.dart';
import 'package:life_pilot/utils/extension.dart';
import 'package:provider/provider.dart';

import '../../../../utils/logger.dart';

class RecommendPlaceCard extends StatelessWidget {
  final bool isExpanded;
  final bool hasRequestedData;
  final ValueChanged<bool> onExpansionChanged;

  const RecommendPlaceCard({
    super.key,
    required this.isExpanded,
    required this.hasRequestedData,
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
    final places = context.select<ModelDashboard, List<RecommendedPlace>>(
      (m) => m.state.recommendPlaces,
    );
    final hasLoadFailed = context.select<ModelDashboard, bool>(
      (m) => m.hasFailed(DashboardSection.recommendPlaces),
    );
    final isLoading = context.select<ModelDashboard, bool>(
      (m) => m.isLoading(DashboardSection.recommendPlaces),
    );

    return Card(
      color: colorScheme.brightness == Brightness.dark
          ? colorScheme.surfaceContainerHigh
          : const Color(0xFFD9E8D5),
      child: Padding(
        padding: Insets.all12,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DashboardCardHeader(
              icon: Icons.local_attraction,
              title: loc.recommendPlaces,
              trailingWidth: isExpanded ? 208 : null,
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isExpanded)
                    const Expanded(child: PlaceCitySelectorButton()),
                  if (!isExpanded)
                    DashboardHeaderSummary(
                      value: hasRequestedData ? places.length.toString() : '—',
                      tooltip: loc.recommendPlaces,
                      isLoading:
                          hasRequestedData && isLoading && places.isEmpty,
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
              if (isLoading && places.isNotEmpty)
                const LinearProgressIndicator(),
              if (hasLoadFailed)
                DashboardLoadFailure(
                  onRetry: () => context.read<ModelDashboard>().retrySection(
                    section: DashboardSection.recommendPlaces,
                    account: account!,
                  ),
                )
              else if (isLoading && places.isEmpty)
                const DashboardSectionLoading()
              else if (places.isEmpty)
                ListTile(
                  leading: Icon(Icons.info_outline),
                  title: Text(loc.noInfoAvailable),
                )
              else
                ...places
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
                                onAccepted: () async {
                                  final calendar = context
                                      .read<CalendarService>();
                                  final calendarController = context
                                      .read<ControllerCalendar>();
                                  final dashboard = context
                                      .read<ModelDashboard>();
                                  try {
                                    bool isExist = await calendar
                                        .existsRecommendedPlaceToCal(
                                          account: account!,
                                          place: e,
                                        );
                                    if (!isExist) {
                                      if (!context.mounted) return;
                                      final now = DateTime.now();
                                      final schedule =
                                          await showScheduleDateTimeDialog(
                                            context,
                                            title: e.name,
                                            initialDate: now,
                                            initialTime: TimeOfDay.fromDateTime(
                                              now,
                                            ),
                                          );
                                      if (schedule == null) return;
                                      final addedEvent = await calendar
                                          .addRecommendedPlaceToCal(
                                            account: account,
                                            place: e,
                                            id: null,
                                            scheduledDate: schedule.date,
                                            scheduledTime: schedule.time,
                                          );
                                      dashboard.addUpcomingEvent(
                                        addedEvent,
                                        account: account,
                                      );
                                      calendarController.invalidateEventCache(
                                        startDate: addedEvent.startDate,
                                        endDate: addedEvent.endDate,
                                      );
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(loc.eventAddOk),
                                          ),
                                        );
                                      }
                                    } else {
                                      final now = DateTime.now();
                                      final schedule =
                                          await showScheduleDateTimeDialog(
                                            context,
                                            title: e.name,
                                            description: loc
                                                .scheduleDuplicateConfirmation,
                                            initialDate: now,
                                            initialTime: TimeOfDay.fromDateTime(
                                              now,
                                            ),
                                          );
                                      if (schedule != null) {
                                        final addedEvent = await calendar
                                            .addRecommendedPlaceToCal(
                                              account: account,
                                              place: e,
                                              id: null,
                                              scheduledDate: schedule.date,
                                              scheduledTime: schedule.time,
                                            );
                                        dashboard.addUpcomingEvent(
                                          addedEvent,
                                          account: account,
                                        );
                                        calendarController.invalidateEventCache(
                                          startDate: addedEvent.startDate,
                                          endDate: addedEvent.endDate,
                                        );
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(loc.eventAddOk),
                                            ),
                                          );
                                        }
                                      }
                                    }
                                    await tracking.incrementEventCounter(
                                      eventId: e.id,
                                      eventName:
                                          e.name, // 或者用 eventViewModel.name
                                      column: 'saves',
                                    ); //收藏到行事曆
                                  } catch (e, stackTrace) {
                                    logger.e(
                                      'Could not add recommended place to calendar.',
                                      error: e,
                                      stackTrace: stackTrace,
                                    );
                                    if (context.mounted) {
                                      final message = subscriptionErrorMessage(
                                        loc,
                                        e,
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
                                },
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
                                e.name,
                                maxLines: 2,
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
                                detail: _recommendedPlaceHours(e),
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
                      PageType.recommendPlaces,
                    );
                  },
                  child: Text(
                    places.length > 5
                        ? loc.viewRemainingRecommendations(places.length - 5)
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

String? _recommendedPlaceHours(RecommendedPlace place) {
  final start = place.startTime?.formatTimeString();
  final end = place.endTime?.formatTimeString();
  if (start == null || start.isEmpty) return null;
  return end == null || end.isEmpty ? start : '$start–$end';
}
