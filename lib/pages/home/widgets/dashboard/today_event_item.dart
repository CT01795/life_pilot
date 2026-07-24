import 'package:flutter/material.dart';
import 'package:life_pilot/auth/model_auth_view.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/pages/home/model/event/calendar_event.dart';
import 'package:life_pilot/pages/home/service/event_tracking_service.dart';
import 'package:life_pilot/utils/const.dart';
import 'package:life_pilot/utils/extension.dart';
import 'package:provider/provider.dart';

class TodayEventItem extends StatelessWidget {
  final CalendarEvent event;
  final ValueChanged<bool?>? onChanged;

  const TodayEventItem({
    super.key,
    required this.event,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final auth = context.watch<ModelAuthView>();
    final tracking = context.read<EventTrackingService>();
    return Padding(
      padding: Insets.all12,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Tooltip(
            message: loc.completeEventTitle,
            child: Transform.scale(
              scale: 1.5, // 放大倍率
              child: Checkbox(
                value: event.isCompleted,
                onChanged: onChanged,
              ),
            ),
          ),
          Gaps.w8,
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Tooltip(
                message: event.masterUrl?.isNotEmpty == true
                    ? loc.clickHereToSeeMore
                    : '',
                child: InkWell(
                  onTap: (event.masterUrl == null || event.masterUrl!.isEmpty)
                      ? null
                      : () async {
                          await tracking.incrementEventCounter(
                            eventId: event.id,
                            eventName: event.name,
                            column: 'page_views',
                            account: auth.account,
                          );
                          await tracking.launchUrlLink(event.masterUrl);
                        },
                  child: Text(
                    '${event.startTime?.formatTimeString() ?? ''} ${event.name}',
                    style: TextStyle(
                      color:
                          (event.masterUrl == null || event.masterUrl!.isEmpty)
                              ? Colors.black
                              : Colors.blue,
                    ),
                  ),
                ),
              ),
              Gaps.h16,
              Tooltip(
                message: ((event.city != null && event.city!.isNotEmpty) ||
                        (event.location != null && event.location!.isNotEmpty))
                    ? loc.openMap
                    : '',
                child: InkWell(
                  onTap: () async {
                    await tracking.incrementEventCounter(
                      eventId: event.id,
                      eventName: event.name,
                      column: 'card_clicks',
                      account: auth.account,
                    );
                    await tracking.onOpenMap(event.city, event.location);
                  },
                  child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if ((event.city != null && event.city!.isNotEmpty) ||
                            (event.location != null &&
                                event.location!.isNotEmpty))
                          const Icon(
                            Icons.location_pin,
                          ),
                        Gaps.w8,
                        Text(
                          '${event.city ?? ''} ${event.location ?? ''}',
                          style: const TextStyle(
                            color: Colors.grey,
                          ),
                        ),
                      ]),
                ),
              ),
              Divider(),
            ],
          ),
        ],
      ),
    );
  }
}
