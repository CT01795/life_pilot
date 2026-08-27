import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:life_pilot/event/controller_event.dart';
import 'package:life_pilot/utils/const.dart';
import 'package:life_pilot/utils/date_time.dart';
import 'package:life_pilot/utils/widgets/widgets_weather_icon.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/event/model_event_item.dart';
import 'package:life_pilot/memory_trace/widgets_memory_sub_card.dart';
import 'package:life_pilot/event/widgets_event_image.dart';
import 'package:life_pilot/utils/weather_localization.dart';
import 'package:life_pilot/utils/model_event_weather.dart';
import 'package:provider/provider.dart';

class WidgetsMemoryCard extends StatelessWidget {
  final ControllerEvent controllerEvent;
  final EventViewModel eventViewModel;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;
  final VoidCallback? onAccounting;
  final VoidCallback onOpenLink;
  final VoidCallback onOpenMap;
  final Widget? trailing;
  final String tableName;
  final bool showSubEvents;

  const WidgetsMemoryCard({
    super.key,
    required this.controllerEvent,
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
    return _WidgetsMemoryCardBody(
      controllerEvent: controllerEvent,
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
    required String text,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.blue,
          decoration: TextDecoration.underline,
        ),
      ),
    );
  }

  static Widget tags({required List<String>? typeList}) {
    if (typeList == null) {
      return SizedBox.shrink();
    }
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: typeList.map((type) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: const Color(0xFFF3E9FA),
            borderRadius: BorderRadius.circular(99),
          ),
          child: Text(
            type,
            style: const TextStyle(
              color: Color(0xFF76528D),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _WidgetsMemoryCardBody extends StatefulWidget {
  final ControllerEvent controllerEvent;
  final EventViewModel eventViewModel;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;
  final VoidCallback? onAccounting;
  final VoidCallback onOpenMap;
  final VoidCallback onOpenLink;
  final Widget? trailing;
  final String tableName;
  final bool showSubEvents;

  const _WidgetsMemoryCardBody({
    required this.controllerEvent,
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
  State<_WidgetsMemoryCardBody> createState() => _WidgetsMemoryCardBodyState();
}

class _WidgetsMemoryCardBodyState extends State<_WidgetsMemoryCardBody> {
  @override
  Widget build(BuildContext context) {
    final now = DateTimeFormatter.dateOnly(DateTime.now());
    final eventDate =
        widget.eventViewModel.endDate ?? widget.eventViewModel.firstEventDate;

    final forecast = context.select<ControllerEvent, List<EventWeather>?>(
      (controller) => controller.getForecast(
        locationDisplay: widget.eventViewModel.locationDisplay,
      ),
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
                            color: Colors.grey.shade300,
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
                  builder: (_) => AlertDialog(
                    title: Text(loc.weatherForecast),
                    content: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(context).size.height * 0.6,
                      ),
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: forecast.map((w) {
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
                                            color: Colors.grey.shade300,
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
                          }).toList(),
                        ),
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(loc.close),
                      ),
                    ],
                  ),
                );
              },
            ),

          Gaps.w8,
          Expanded(
              child: Text(
            widget.eventViewModel.name,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 18,
              height: 1.25,
              color: Color(0xFF31263A),
            ),
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

    Widget infoRow(IconData icon, String text, {VoidCallback? onTap}) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 18, color: const Color(0xFF8A668F)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  text,
                  style: const TextStyle(
                    color: Color(0xFF62536A),
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final content = Padding(
      padding: const EdgeInsets.fromLTRB(16, 15, 16, 50),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          buildHeader(),
          const SizedBox(height: 10),
          if (widget.eventViewModel.dateRange.isNotEmpty)
            infoRow(
                Icons.calendar_month_rounded, widget.eventViewModel.dateRange),
          if (widget.eventViewModel.hasLocation)
            infoRow(
              Icons.place_rounded,
              widget.eventViewModel.locationDisplay,
              onTap: widget.onOpenMap,
            ),
          if (widget.eventViewModel.tags.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 7),
              child:
                  WidgetsMemoryCard.tags(typeList: widget.eventViewModel.tags),
            ),
          if (widget.eventViewModel.description.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                widget.eventViewModel.description,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF6D5D72),
                  height: 1.45,
                ),
              ),
            ),
          if (widget.eventViewModel.masterUrl?.isNotEmpty == true)
            Padding(
              padding: const EdgeInsets.only(top: 7),
              child: TextButton.icon(
                onPressed: widget.onOpenLink,
                icon: const Icon(Icons.open_in_new_rounded, size: 17),
                label: Text(loc.clickHereToSeeMore),
              ),
            ),
          if (widget.showSubEvents &&
              widget.eventViewModel.subEvents.isNotEmpty)
            Column(
              children: [
                for (final sub in widget.eventViewModel.subEvents)
                  WidgetsMemorySubCard(
                    key: ValueKey(sub.id),
                    event: sub,
                    onOpenLink: widget.onOpenLink,
                  ),
              ],
            )
        ],
      ),
    );

    final container = Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Color(0xFFEADFEB)),
      ),
      color: const Color(0xFFFFFBFF),
      surfaceTintColor: Colors.white,
      elevation: 1.5,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          WidgetsEventImage(value: widget.eventViewModel.masterGraphUrl),
          content,
        ],
      ),
    );

    return GestureDetector(
      onTap: widget.eventViewModel.subEvents.isEmpty ? null : widget.onTap,
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
                    icon: const Icon(Icons.delete, color: Colors.redAccent),
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
