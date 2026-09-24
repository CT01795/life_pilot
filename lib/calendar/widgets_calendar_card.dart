import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:intl/intl.dart';
import 'package:life_pilot/calendar/controller_calendar.dart';
import 'package:life_pilot/event/model_event_item.dart';
import 'package:life_pilot/utils/const.dart';
import 'package:life_pilot/utils/date_time.dart';
import 'package:life_pilot/utils/widgets/widgets_weather_icon.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/calendar/widgets_calendar_sub_card.dart';
import 'package:life_pilot/utils/model_event_weather.dart';
import 'package:provider/provider.dart';
import 'package:life_pilot/utils/weather_localization.dart';

class WidgetsCalendarCard extends StatelessWidget {
  final EventViewModel eventViewModel;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;
  final VoidCallback? onAccounting;
  final VoidCallback? onPoints;
  final VoidCallback onOpenMap;
  final VoidCallback onOpenLink;
  final Widget? trailing;
  final String tableName;
  final bool showSubEvents;

  const WidgetsCalendarCard({
    super.key,
    required this.eventViewModel,
    required this.tableName,
    this.onTap,
    this.onDelete,
    this.onAccounting,
    this.onPoints,
    required this.onOpenMap,
    required this.onOpenLink,
    this.trailing,
    this.showSubEvents = true,
  });

  @override
  Widget build(BuildContext context) {
    return _WidgetsCalendarCardBody(
      eventViewModel: eventViewModel,
      tableName: tableName,
      onTap: onTap,
      onDelete: onDelete,
      onAccounting: onAccounting,
      onPoints: onPoints,
      onOpenMap: onOpenMap,
      onOpenLink: onOpenLink,
      trailing: trailing,
      showSubEvents: showSubEvents,
    );
  }

  static Widget link({
    required BuildContext context,
    required String text,
    required VoidCallback? onTap,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      child: Text(
        text,
        style: TextStyle(
          color: colorScheme.primary,
          decoration: TextDecoration.underline,
        ),
      ),
    );
  }

  static Widget tags({
    required BuildContext context,
    required List<String>? typeList,
  }) {
    if (typeList == null) {
      return const SizedBox.shrink();
    }
    final colorScheme = Theme.of(context).colorScheme;
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: typeList.map((type) {
        return Container(
          padding: Insets.h8v4,
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer,
            border: Border.all(color: colorScheme.primary),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            type,
            style: TextStyle(color: colorScheme.onPrimaryContainer),
          ),
        );
      }).toList(),
    );
  }
}

class _WidgetsCalendarCardBody extends StatelessWidget {
  final EventViewModel eventViewModel;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;
  final VoidCallback? onAccounting;
  final VoidCallback? onPoints;
  final VoidCallback onOpenMap;
  final VoidCallback onOpenLink;
  final Widget? trailing;
  final String tableName;
  final bool showSubEvents;

  const _WidgetsCalendarCardBody({
    required this.eventViewModel,
    required this.tableName,
    this.onTap,
    this.onDelete,
    this.onAccounting,
    this.onPoints,
    required this.onOpenMap,
    required this.onOpenLink,
    this.trailing,
    this.showSubEvents = true,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTimeFormatter.dateOnly(DateTime.now());
    final eventDate = eventViewModel.endDate ?? eventViewModel.firstEventDate;

    // 使用 Selector 只監聽對應 event 的天氣
    final forecast = context.select<ControllerCalendar, List<EventWeather>?>(
      (c) => c.getForecast(locationDisplay: eventViewModel.locationDisplay),
    );

    final showWeatherIcon =
        forecast != null && forecast.isNotEmpty && !eventDate.isBefore(now);

    final todayWeather = forecast != null && forecast.isNotEmpty
        ? forecast.first
        : null;

    final loc = AppLocalizations.of(context)!;
    Widget buildHeader() {
      return Row(
        children: [
          // 天氣 Icon
          if (showWeatherIcon && todayWeather != null)
            IconButton(
              icon: Container(
                width: 42,
                height: 42,
                decoration:
                    todayWeather.main == 'Clouds' || todayWeather.main == 'Rain'
                    ? BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerHighest,
                        shape: BoxShape.circle,
                      )
                    : null,
                padding: const EdgeInsets.all(1),
                child: WidgetsWeatherIcon(icon: todayWeather.icon),
              ),
              tooltip:
                  '${localizeWeatherCondition(loc, todayWeather.main)} ${todayWeather.temp.toStringAsFixed(1)}°C',
              onPressed: () async {
                if (!context.mounted) return;
                showDialog(
                  context: context,
                  builder: (dialogContext) {
                    final maxHeight =
                        MediaQuery.sizeOf(dialogContext).height * 0.6;
                    final contentHeight = (forecast.length * 104.0)
                        .clamp(120.0, maxHeight)
                        .toDouble();
                    return AlertDialog(
                      title: Text(loc.weatherForecast),
                      content: SizedBox(
                        width: MediaQuery.sizeOf(
                          dialogContext,
                        ).width.clamp(0, 420).toDouble(),
                        height: contentHeight,
                        child: ListView.builder(
                          itemCount: forecast.length,
                          scrollCacheExtent: const ScrollCacheExtent.pixels(
                            208,
                          ),
                          addAutomaticKeepAlives: false,
                          itemBuilder: (context, index) {
                            final w = forecast[index];
                            String tmp =
                                '${loc.weatherTemperature}: ${w.temp.toStringAsFixed(1)}°C';
                            if (w.temp.toStringAsFixed(1) !=
                                w.tempMin.toStringAsFixed(1)) {
                              tmp =
                                  '$tmp\n${loc.weatherMinimum}: ${w.tempMin.toStringAsFixed(1)}°C';
                            }
                            if (w.temp.toStringAsFixed(1) !=
                                w.tempMax.toStringAsFixed(1)) {
                              tmp =
                                  '$tmp\n${loc.weatherMaximum}: ${w.tempMax.toStringAsFixed(1)}°C';
                            }
                            tmp = '$tmp\n';
                            return ListTile(
                              leading: Container(
                                width: 42,
                                height: 42,
                                decoration:
                                    w.main == 'Clouds' || w.main == 'Rain'
                                    ? BoxDecoration(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.surfaceContainerHighest,
                                        shape: BoxShape.circle,
                                      )
                                    : null,
                                padding: const EdgeInsets.all(1),
                                child: WidgetsWeatherIcon(icon: w.icon),
                              ),
                              title: Text(
                                '${DateFormat.Md(loc.localeName).add_Hm().format(w.date)} ${localizeWeatherCondition(loc, w.main)}',
                              ),
                              subtitle: Text(tmp),
                            );
                          },
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(dialogContext),
                          child: Text(loc.close),
                        ),
                      ],
                    );
                  },
                );
              },
            ),

          Gaps.w8,
          Expanded(
            child: Text(
              eventViewModel.name,
              style: const TextStyle(fontWeight: FontWeight.bold),
              softWrap: true, // 允許換行
              overflow: TextOverflow.visible, // 文字超過不截斷
              //overflow: TextOverflow.ellipsis, // 防止文字過長
            ),
          ),
          if (trailing != null)
            Builder(
              builder: (context) {
                // 這裡的 context 已經在 widget 樹內，可以安全使用 Provider
                return trailing!;
              },
            ),
        ],
      );
    }

    final content = Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 52),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          buildHeader(),
          if (eventViewModel.dateRange.isNotEmpty)
            Text(eventViewModel.dateRange),
          if (eventViewModel.tags.isNotEmpty)
            WidgetsCalendarCard.tags(
              context: context,
              typeList: eventViewModel.tags,
            ),
          if (eventViewModel.hasLocation)
            InkWell(
              onTap: onOpenMap,
              child: Text(
                eventViewModel.locationDisplay,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          if (eventViewModel.masterUrl?.isNotEmpty == true)
            WidgetsCalendarCard.link(
              context: context,
              text: loc.clickHereToSeeMore,
              onTap: onOpenLink,
            ),
          if (eventViewModel.description.isNotEmpty)
            Text(eventViewModel.description),
          if (showSubEvents && eventViewModel.subEvents.isNotEmpty)
            Column(
              children: [
                for (final sub in eventViewModel.subEvents)
                  WidgetsCalendarSubCard(
                    key: ValueKey(sub.id),
                    event: sub,
                    onOpenLink: onOpenLink,
                  ),
              ],
            ),
        ],
      ),
    );

    final container = Container(margin: Insets.h8v16, child: content);

    return GestureDetector(
      onTap: eventViewModel.subEvents.isNotEmpty ? onTap : null,
      child: Stack(
        children: [
          container,
          PositionedDirectional(
            end: Gaps.w16.width,
            bottom: Gaps.h8.height,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (onAccounting != null)
                  IconButton(
                    icon: Icon(Icons.currency_exchange),
                    tooltip: loc.accountRecords,
                    onPressed: onAccounting,
                  ),
                if (onPoints != null)
                  IconButton(
                    icon: const Icon(Icons.stars_rounded),
                    tooltip: loc.pointsRecord,
                    onPressed: onPoints,
                  ),
                // 🗑 Delete（只有 canDelete）
                if (eventViewModel.canDelete && onDelete != null)
                  IconButton(
                    icon: Icon(
                      Icons.delete,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    tooltip: loc.delete,
                    onPressed: onDelete,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
