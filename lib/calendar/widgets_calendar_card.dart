import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:life_pilot/calendar/controller_calendar.dart';
import 'package:life_pilot/event/model_event_item.dart';
import 'package:life_pilot/utils/const.dart';
import 'package:life_pilot/utils/date_time.dart';
import 'package:life_pilot/utils/graph.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/calendar/widgets_calendar_sub_card.dart';
import 'package:life_pilot/utils/model_event_weather.dart';
import 'package:provider/provider.dart';

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

  static Widget link(
      {required String text,
        required VoidCallback? onTap,}) {
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
          padding: Insets.h8v4,
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            border: Border.all(color: Colors.blue),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            type,
            style: const TextStyle(color: Colors.blue),
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

class _WidgetsCalendarCardBodyState
    extends State<_WidgetsCalendarCardBody> {
  
  bool _weatherLoaded = false;
   final Map<String, bool> _assetCache = {}; // 緩存 asset 檢查結果

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (!_weatherLoaded) {
      final ctrl = context.read<ControllerCalendar>();
      ctrl.loadWeather(widget.eventViewModel);
      _weatherLoaded = true;
    }
  }

  Future<bool> _cachedAssetExists(String path) async {
    if (_assetCache.containsKey(path)) return _assetCache[path]!;
    final exists = await assetExists(path);
    _assetCache[path] = exists;
    return exists;
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTimeFormatter.dateOnly(DateTime.now());
    final eventDate = widget.eventViewModel.firstEventDate;

    // 使用 Selector 只監聽對應 event 的天氣
    final forecast = context.select<ControllerCalendar, List<EventWeather>?>(
      (c) => c.getForecast(widget.eventViewModel.id),
    );

    final showWeatherIcon = forecast != null && forecast.isNotEmpty && !eventDate.isBefore(now);

    final todayWeather = forecast != null && forecast.isNotEmpty ? forecast.first : null;

    final loc = AppLocalizations.of(context)!;
    Widget buildHeader() {
      return Row(
        children: [
          // 天氣 Icon
          if (showWeatherIcon && todayWeather != null && context.mounted)
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
                child: FutureBuilder<bool>(
                  future: _cachedAssetExists(
                      'assets/weather_icons/${todayWeather.icon}.png'),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const SizedBox(width: 40, height: 40);
                    }
                    final exists = snapshot.data ?? false;
                    return exists
                        ? Image.asset(
                            'assets/weather_icons/${todayWeather.icon}.png',
                            width: 40,
                            height: 40,
                          )
                        : Image.network(
                            'https://openweathermap.org/img/wn/${todayWeather.icon}.png',
                            width: 40,
                            height: 40,
                          );
                  },
                ),
              ),
              tooltip:
                  '${todayWeather.main} ${todayWeather.temp.toStringAsFixed(1)}°C',
              onPressed: () async {
                if (!context.mounted) return;
                showDialog(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: Text('Weather Forecast'),
                    content: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(context).size.height * 0.6,
                      ),
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: forecast.map((w) {
                            String tmp =
                                '${w.description}\nTemperature: ${w.temp.toStringAsFixed(1)}°C';
                            if (w.temp.toStringAsFixed(1) !=
                                w.tempMin.toStringAsFixed(1)) {
                              tmp =
                                  '$tmp\nMin:${w.tempMin.toStringAsFixed(1)}°C';
                            }
                            if (w.temp.toStringAsFixed(1) !=
                                w.tempMax.toStringAsFixed(1)) {
                              tmp =
                                  '$tmp~Max:${w.tempMax.toStringAsFixed(1)}°C';
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
                                child: FutureBuilder<bool>(
                                  future: _cachedAssetExists(
                                      'assets/weather_icons/${w.icon}.png'),
                                  builder: (context, snapshot) {
                                    if (snapshot.connectionState !=
                                        ConnectionState.done) {
                                      return const SizedBox(
                                          width: 40, height: 40);
                                    }
                                    final exists = snapshot.data ?? false;
                                    return exists
                                        ? Image.asset(
                                            'assets/weather_icons/${w.icon}.png',
                                            width: 40,
                                            height: 40,
                                          )
                                        : Image.network(
                                            'https://openweathermap.org/img/wn/${w.icon}.png',
                                            width: 40,
                                            height: 40,
                                          );
                                  },
                                ),
                              ),
                              title: Text(
                                  '${DateFormat('M/d H:mm').format(w.date)} ${w.main}'),
                              subtitle: Text(tmp),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text('Close'),
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
            WidgetsCalendarCard.tags(typeList: widget.eventViewModel.tags),
          if (widget.eventViewModel.hasLocation)
            InkWell(
              onTap: widget.onOpenMap,
              child: Text(
                widget.eventViewModel.locationDisplay,
                style: const TextStyle(
                  color: Colors.blue,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          if (widget.eventViewModel.masterUrl?.isNotEmpty == true)
            WidgetsCalendarCard.link(
                text: loc.clickHereToSeeMore,
                onTap: widget.onOpenLink,),
          if (widget.eventViewModel.description.isNotEmpty)
            Text(widget.eventViewModel.description),
          if (widget.showSubEvents)
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: widget.eventViewModel.subEvents.length,
              itemBuilder: (context, index) {
                final sub = widget.eventViewModel.subEvents[index];
                return WidgetsCalendarSubCard(event: sub, onOpenLink: widget.onOpenLink,);
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
