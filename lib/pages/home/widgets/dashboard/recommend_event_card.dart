import 'package:flutter/material.dart';
import 'package:life_pilot/apps/controller_page_main.dart';
import 'package:life_pilot/auth/model_auth_view.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/pages/home/model/event/recommended_event.dart';
import 'package:life_pilot/pages/home/model/dashboard/model_dashboard.dart';
import 'package:life_pilot/pages/home/service/event_tracking_service.dart';
import 'package:life_pilot/pages/home/widgets/dashboard/event_city_selector_button.dart';
import 'package:life_pilot/pages/home/widgets/dashboard/dashboard_card_header.dart';
import 'package:life_pilot/utils/const.dart';
import 'package:life_pilot/utils/enum.dart';
import 'package:life_pilot/utils/extension.dart';
import 'package:provider/provider.dart';

class RecommendEventCard extends StatelessWidget {
  const RecommendEventCard({super.key});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final auth = context.watch<ModelAuthView>();
    final tracking = context.read<EventTrackingService>();
    final today = DateUtils.dateOnly(DateTime.now());
    final events = context.select<ModelDashboard, List<RecommendedEvent>>(
      (m) => m.state.recommendEvents,
    );

    return Card(
      color: Color(0xFFF1E1CF),
      child: Padding(
        padding: Insets.all12,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DashboardCardHeader(
              icon: Icons.local_activity,
              title: loc.recommendEvent,
              trailing: EventCitySelectorButton(),
            ),
            Gaps.h16,
            if (events.isEmpty)
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: Text(loc.noInfoAvailable),
              )
            else
              ...events.take(5).map(
                  (e) => ListTile(
                    leading: Tooltip(
                      message: loc.addToSchedule,
                      child: Transform.scale(
                        scale: 1.5, // 放大倍率
                        child: Checkbox(
                          value: false,
                          onChanged: null, //TODO 接行事曆
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
                                  account: auth.account,
                                );
                                await tracking.launchUrlLink(e.masterUrl);
                              },
                        child: Text(
                          '${(e.startDate!.isBefore(today) ? '～ ${e.endDate?.formatDateString()}' : e.startDate?.formatDateString())} ${e.startTime?.formatTimeString() ?? ''}\n${e.name}',
                          style: TextStyle(
                            color: (e.masterUrl == null || e.masterUrl!.isEmpty)
                                ? Colors.black
                                : Colors.blue,
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
                                (e.location != null && e.location!.isNotEmpty))
                            ? () async {
                                await tracking.incrementEventCounter(
                                  eventId: e.id,
                                  eventName: e.name,
                                  column: 'card_clicks',
                                  account: auth.account,
                                );
                                await tracking.onOpenMap(e.city, e.location);
                              }
                            : null,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if ((e.city != null && e.city!.isNotEmpty) ||
                                (e.location != null && e.location!.isNotEmpty))
                              const Icon(
                                Icons.location_on,
                              ),
                            Gaps.w8,
                            Flexible(
                              child: Text(
                                '${e.city ?? ''} ${e.location ?? ''}',
                                style: const TextStyle(
                                  color: Colors.grey,
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
                      .changePage(PageType.recommendEvent);
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
