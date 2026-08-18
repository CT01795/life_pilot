import 'package:flutter/material.dart';
import 'package:life_pilot/apps/controller_page_main.dart';
import 'package:life_pilot/auth/model_auth_view.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/pages/home/model/dashboard/model_dashboard.dart';
import 'package:life_pilot/pages/home/model/place/recommended_place.dart';
import 'package:life_pilot/pages/home/service/calendar_service.dart';
import 'package:life_pilot/pages/home/service/event_tracking_service.dart';
import 'package:life_pilot/pages/home/widgets/dashboard/dashboard_card_header.dart';
import 'package:life_pilot/pages/home/widgets/dashboard/async_action_checkbox.dart';
import 'package:life_pilot/pages/home/widgets/dashboard/dashboard_load_failure.dart';
import 'package:life_pilot/pages/home/widgets/dashboard/place_selector_button.dart';
import 'package:life_pilot/utils/const.dart';
import 'package:life_pilot/utils/enum.dart';
import 'package:life_pilot/utils/extension.dart';
import 'package:provider/provider.dart';

import '../../../../utils/logger.dart';

class RecommendPlaceCard extends StatelessWidget {
  const RecommendPlaceCard({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final auth = context.watch<ModelAuthView>();
    final tracking = context.read<EventTrackingService>();
    final places = context.select<ModelDashboard, List<RecommendedPlace>>(
      (m) => m.state.recommendPlaces,
    );
    final hasLoadFailed = context.select<ModelDashboard, bool>(
      (m) => m.hasFailed(DashboardSection.recommendPlaces),
    );

    return Card(
      color: Color(0xFFD9E8D5),
      child: Padding(
        padding: Insets.all12,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DashboardCardHeader(
              icon: Icons.local_attraction,
              title: loc.recommendPlaces,
              trailing: PlaceCitySelectorButton(),
            ),
            Gaps.h16,
            if (hasLoadFailed)
              DashboardLoadFailure(
                onRetry: () => context.read<ModelDashboard>().refreshAll(
                      account: auth.account!,
                    ),
              )
            else if (places.isEmpty)
              ListTile(
                leading: Icon(Icons.info_outline),
                 title: Text(loc.noInfoAvailable),
              )
            else
              ...places.take(5).map(
                  (e) => ListTile(
                    leading: Tooltip(
                      message: loc.addToSchedule,
                      child: Transform.scale(
                        scale: 1.5, // 放大倍率
                        child: AsyncActionCheckbox(
                          onAccepted: () async {
                            final calendar = context.read<CalendarService>();
                            try {
                              bool isExist =
                                  await calendar.existsRecommendedPlaceToCal(
                                      account: auth.account!, place: e);
                              if (!isExist) {
                                await calendar.addRecommendedPlaceToCal(
                                    account: auth.account!,
                                    place: e,
                                    id: null);
                                context.read<ModelDashboard>().refreshTodaySchedule(account: auth.account!);
                                ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                        content: Text(loc.eventAddOk)));
                              } else {
                                final confirm = await showDialog<bool>(
                                    context: context,
                                    builder: (_) => AlertDialog(
                                          content: Text('「${e.name}」${loc.eventAddError}'),
                                          actions: [
                                            TextButton(
                                                onPressed: () {
                                                  Navigator.pop(
                                                      context, false);
                                                },
                                                child: Text(loc.cancel)),
                                            TextButton(
                                                onPressed: () async {
                                                  Navigator.pop(
                                                      context, true);
                                                },
                                                child: Text(loc.confirm))
                                          ],
                                        ));
                                if (confirm == true) {
                                  await calendar.addRecommendedPlaceToCal(
                                      account: auth.account!,
                                      place: e,
                                      id: null);
                                  context.read<ModelDashboard>().refreshTodaySchedule(account: auth.account!);
                                  ScaffoldMessenger.of(context)
                                      .showSnackBar(SnackBar(
                                          content: Text(loc.eventAddOk)));
                                }
                              }
                              await tracking.incrementEventCounter(
                                  eventId: e.id,
                                  eventName: e.name, // 或者用 eventViewModel.name
                                  column: 'saves', //收藏到行事曆
                                  account: auth.account ?? AuthConstants.guest);
                            } catch (e, stackTrace) {
                              logger.e(
                                'Could not add recommended place to calendar.',
                                error: e,
                                stackTrace: stackTrace,
                              );
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(loc.eventSaveFailed)),
                                );
                              }
                            }
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
                          '${e.startTime?.formatTimeString() ?? ''} ${e.name}',
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
                      .changePage(PageType.recommendPlaces);
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
