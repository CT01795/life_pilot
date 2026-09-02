import 'package:flutter/material.dart';
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

class _WidgetsCalendarCardBody extends StatefulWidget {
  final EventViewModel eventViewModel;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;
  final VoidCallback? onAccounting;
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
    required this.onOpenMap,
    required this.onOpenLink,
    this.trailing,
    this.showSubEvents = true,
  });

  @override
  State<_WidgetsCalendarCardBody> createState() =>
      _WidgetsCalendarCardBodyState();
}

class _WidgetsCalendarCardBodyState extends State<_WidgetsCalendarCardBody> {
  @override
  Widget build(BuildContext context) {
    final now = DateTimeFormatter.dateOnly(DateTime.now());
    final eventDate =
        widget.eventViewModel.endDate ?? widget.eventViewModel.firstEventDate;

    // 使用 Selector 只監聽對應 event 的天氣
    final forecast = context.select<ControllerCalendar, List<EventWeather>?>(
      (c) =>
          c.getForecast(locationDisplay: widget.eventViewModel.locationDisplay),
    );

    final showWeatherIcon =
        forecast != null && forecast.isNotEmpty && !eventDate.isBefore(now);

    final todayWeather =
        forecast != null && forecast.isNotEmpty ? forecast.first : null;

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
                            color: Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest,
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
                        width: 420,
                        height: contentHeight,
                        child: ListView.builder(
                          itemCount: forecast.length,
                          cacheExtent: 208,
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
                                            color: Theme.of(context)
                                                .colorScheme
                                                .surfaceContainerHighest,
                                            shape: BoxShape.circle,
                                          )
                                        : null,
                                padding: const EdgeInsets.all(1),
                                child: WidgetsWeatherIcon(icon: w.icon),
                              ),
                              title: Text(
                                  '${DateFormat.Md(loc.localeName).add_Hm().format(w.date)} ${localizeWeatherCondition(loc, w.main)}'),
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
            widget.eventViewModel.name,
            style: const TextStyle(fontWeight: FontWeight.bold),
            softWrap: true, // 允許換行
            overflow: TextOverflow.visible, // 文字超過不截斷
            //overflow: TextOverflow.ellipsis, // 防止文字過長
          )),
          if (widget.trailing != null)
            Builder(
              builder: (context) {
                // 這裡的 context 已經在 widget 樹內，可以安全使用 Provider
                return widget.trailing!;
              },
            ),
        ],
      );
    }

    final content = Padding(
      padding: Insets.all4,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          buildHeader(),
          if (widget.eventViewModel.dateRange.isNotEmpty)
            Text(widget.eventViewModel.dateRange),
          if (widget.eventViewModel.tags.isNotEmpty)
            WidgetsCalendarCard.tags(
              context: context,
              typeList: widget.eventViewModel.tags,
            ),
          if (widget.eventViewModel.hasLocation)
            InkWell(
              onTap: widget.onOpenMap,
              child: Text(
                widget.eventViewModel.locationDisplay,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          if (widget.eventViewModel.masterUrl?.isNotEmpty == true)
            WidgetsCalendarCard.link(
              context: context,
              text: loc.clickHereToSeeMore,
              onTap: widget.onOpenLink,
            ),
          if (widget.eventViewModel.description.isNotEmpty)
            Text(widget.eventViewModel.description),
          if (widget.showSubEvents &&
              widget.eventViewModel.subEvents.isNotEmpty)
            ListView.builder(
              shrinkWrap: true, // 讓 ListView 自動高度
              physics:
                  const NeverScrollableScrollPhysics(), // 禁止 ListView 滾動，交給外層 ScrollView
              itemCount: widget.eventViewModel.subEvents.length,
              itemBuilder: (context, index) {
                final sub = widget.eventViewModel.subEvents[index];
                return WidgetsCalendarSubCard(
                  event: sub,
                  onOpenLink: widget.onOpenLink,
                );
              },
            )
        ],
      ),
    );

    final container = Container(
      margin: Insets.h8v16,
      child: content,
    );

    return GestureDetector(
      onTap: widget.eventViewModel.subEvents.isNotEmpty ? widget.onTap : null,
      child: Stack(
        children: [
          container,
          PositionedDirectional(
            end: Gaps.w16.width,
            bottom: Gaps.h8.height,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.onAccounting != null)
                  IconButton(
                    icon: Icon(Icons.currency_exchange),
                    tooltip: loc.accountRecords,
                    onPressed: widget.onAccounting,
                  ),
                // 🗑 Delete（只有 canDelete）
                if (widget.eventViewModel.canDelete && widget.onDelete != null)
                  IconButton(
                    icon: Icon(
                      Icons.delete,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    tooltip: loc.delete,
                    onPressed: widget.onDelete,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
