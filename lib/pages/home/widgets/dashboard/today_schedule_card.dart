import 'package:flutter/material.dart';
import 'package:life_pilot/apps/controller_page_main.dart';
import 'package:life_pilot/auth/model_auth_view.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/pages/home/model/event/calendar_event.dart';
import 'package:life_pilot/pages/home/model/dashboard/model_dashboard.dart';
import 'package:life_pilot/pages/home/service/event_tracking_service.dart';
import 'package:life_pilot/utils/const.dart';
import 'package:life_pilot/utils/enum.dart';
import 'package:life_pilot/utils/extension.dart';
import 'package:provider/provider.dart';

class TodayScheduleCard extends StatelessWidget {
  const TodayScheduleCard({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final auth = context.watch<ModelAuthView>();
    final tracking = context.read<EventTrackingService>();
    final events = context.select<ModelDashboard, List<CalendarEvent>>(
      (m) => m.state.todayEvents
          .where(
            (e) => !e.isCompleted,
          )
          .toList(),
    );

    return Card(
      color: Color(0xFFD6E4F0),
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
            if (events.isEmpty)
              ListTile(
                leading: Icon(Icons.info_outline),
                 title: Text(loc.noInfoAvailable),
              )
            else
              ...events.map(
                  (e) => ListTile(
                    leading: Tooltip(
                      message: loc.completeEventTitle,
                      child: Transform.scale(
                        scale: 1.5, // 放大倍率
                        child: Checkbox(
                            value: false,
                            onChanged: (value) async {
                              if (value != true) {
                                return;
                              }

                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (context) {
                                  final loc = AppLocalizations.of(context)!;

                                  return AlertDialog(
                                    title: Text(
                                      loc.completeEventTitle,
                                    ),
                                    content: Text(
                                      loc.completeEventMessage,
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () {
                                          Navigator.pop(
                                            context,
                                            false,
                                          );
                                        },
                                        child: Text(
                                          loc.cancel,
                                        ),
                                      ),
                                      ElevatedButton(
                                        onPressed: () {
                                          Navigator.pop(
                                            context,
                                            true,
                                          );
                                        },
                                        child: Text(
                                          loc.confirm,
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              );

                              if (confirm != true) {
                                return;
                              }

                              final account =
                                  context.read<ModelAuthView>().account;

                              if (account == null) {
                                return;
                              }

                              await context
                                  .read<ModelDashboard>()
                                  .completeEvent(
                                    id: e.id,
                                    account: account,
                                  );
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
                                  account: auth.account,
                                );
                                await tracking.launchUrlLink(e.masterUrl);
                              },
                        child: Text(
                          '${e.startDate?.formatDateString() == DateTime.now().formatDateString() ? '' : e.startDate?.formatDateString()} ${e.startTime?.formatTimeString() ?? ''} ${e.name}',
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
