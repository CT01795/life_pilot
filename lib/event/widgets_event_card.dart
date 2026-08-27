// lib/views/widgets/event/event_card_widgets.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:life_pilot/event/controller_event.dart';
import 'package:life_pilot/event/widgets_event_utils.dart';
import 'package:life_pilot/utils/const.dart';
import 'package:life_pilot/utils/date_time.dart';
import 'package:life_pilot/utils/graph.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/event/model_event_item.dart';
import 'package:life_pilot/event/widgets_event_sub_card.dart';
import 'package:life_pilot/event/widgets_event_image.dart';
import 'package:life_pilot/utils/weather_localization.dart';

class WidgetsEventCard extends StatelessWidget {
  final ControllerEvent controllerEvent;
  final EventViewModel eventViewModel;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;
  final Future<void> Function()? onLike;
  final Future<void> Function()? onDislike;
  final VoidCallback? onAccounting;
  final VoidCallback onOpenLink;
  final VoidCallback onOpenMap;
  final Widget? trailing;
  final String tableName;
  final bool showSubEvents;

  const WidgetsEventCard({
    super.key,
    required this.controllerEvent,
    required this.eventViewModel,
    required this.tableName,
    this.onTap,
    this.onDelete,
    this.onLike,
    this.onDislike,
    this.onAccounting,
    required this.onOpenMap,
    required this.onOpenLink,
    this.trailing,
    this.showSubEvents = true,
  });

  @override
  Widget build(BuildContext context) {
    return _WidgetsEventCardBody(
      controllerEvent: controllerEvent,
      eventViewModel: eventViewModel,
      tableName: tableName,
      onTap: onTap,
      onDelete: onDelete,
      onLike: onLike,
      onDislike: onDislike,
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
            color: const Color(0xFFE8F1FF),
            borderRadius: BorderRadius.circular(99),
          ),
          child: Text(
            type,
            style: const TextStyle(
              color: Color(0xFF315C9B),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _WidgetsEventCardBody extends StatefulWidget {
  final ControllerEvent controllerEvent;
  final EventViewModel eventViewModel;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;
  final Future<void> Function()? onLike;
  final Future<void> Function()? onDislike;
  final VoidCallback? onAccounting;
  final VoidCallback onOpenMap;
  final VoidCallback onOpenLink;
  final Widget? trailing;
  final String tableName;
  final bool showSubEvents;

  const _WidgetsEventCardBody({
    required this.controllerEvent,
    required this.eventViewModel,
    required this.tableName,
    this.onTap,
    this.onDelete,
    this.onLike,
    this.onDislike,
    this.onAccounting,
    required this.onOpenMap,
    required this.onOpenLink,
    this.trailing,
    this.showSubEvents = true,
  });

  @override
  State<_WidgetsEventCardBody> createState() => _WidgetsEventCardBodyState();
}

class _WidgetsEventCardBodyState extends State<_WidgetsEventCardBody> {
  final Map<String, bool> _assetCache = {}; // 緩存 asset 檢查結果

  Future<bool> _cachedAssetExists(String path) async {
    if (_assetCache.containsKey(path)) return _assetCache[path]!;
    final exists = await assetExists(path);
    _assetCache[path] = exists;
    return exists;
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTimeFormatter.dateOnly(DateTime.now());
    final eventDate =
        widget.eventViewModel.endDate ?? widget.eventViewModel.firstEventDate;

    final forecast = widget.controllerEvent
        .getForecast(locationDisplay: widget.eventViewModel.locationDisplay);

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
                                '${localizeWeatherCondition(loc, w.main)}\n${loc.weatherTemperature}: ${w.temp.toStringAsFixed(1)}°C';
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
              color: Color(0xFF1C2733),
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
              Icon(icon, size: 18, color: const Color(0xFF5C6F82)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  text,
                  style: const TextStyle(
                    color: Color(0xFF46586A),
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    Widget dateBanner(String text) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF0EC),
          borderRadius: BorderRadius.circular(12),
          border: const Border(
            left: BorderSide(color: Color(0xFFE9573F), width: 4),
          ),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.event_available_rounded,
              size: 20,
              color: Color(0xFFD84532),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(
                  color: Color(0xFF8A3025),
                  fontWeight: FontWeight.w800,
                  height: 1.3,
                ),
              ),
            ),
          ],
        ),
      );
    }

    Widget placeLocation(String text) {
      return InkWell(
        onTap: widget.onOpenMap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 4),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFE8F7F2), Color(0xFFEAF4FB)],
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const Icon(Icons.explore_rounded,
                  color: Color(0xFF167D72), size: 22),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  text,
                  style: const TextStyle(
                    color: Color(0xFF17675F),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const Icon(Icons.directions_rounded,
                  color: Color(0xFF347F9B), size: 19),
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
            dateBanner(widget.eventViewModel.dateRange),
          if (widget.eventViewModel.dateRange.isNotEmpty &&
              widget.eventViewModel.tags.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 9),
              child:
                  WidgetsEventCard.tags(typeList: widget.eventViewModel.tags),
            ),
          if (widget.eventViewModel.hasLocation)
            widget.tableName == TableNames.recommendPlaces
                ? placeLocation(widget.eventViewModel.locationDisplay)
                : infoRow(
                    Icons.location_on_rounded,
                    widget.eventViewModel.locationDisplay,
                    onTap: widget.onOpenMap,
                  ),
          if (widget.eventViewModel.dateRange.isEmpty &&
              widget.eventViewModel.tags.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 7),
              child:
                  WidgetsEventCard.tags(typeList: widget.eventViewModel.tags),
            ),
          if (widget.eventViewModel.description.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                widget.eventViewModel.description,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF5D6874),
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
            ListView.builder(
              shrinkWrap: true, // 讓 ListView 自動高度
              physics:
                  const NeverScrollableScrollPhysics(), // 禁止 ListView 滾動，交給外層 ScrollView
              itemCount: widget.eventViewModel.subEvents.length,
              itemBuilder: (context, index) {
                final sub = widget.eventViewModel.subEvents[index];
                return WidgetsEventSubCard(
                  event: sub,
                  onOpenLink: widget.onOpenLink,
                );
              },
            )
        ],
      ),
    );

    final container = Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Color(0xFFE4EAF0)),
      ),
      color: Colors.white,
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
                // 👍 Favor（登入即可）
                if (widget.onLike != null)
                  PressButton(
                    isPress: widget.eventViewModel.isLike,
                    color: Colors.pinkAccent,
                    onPressed: widget.onLike,
                    pressedIcon: Icons.favorite_outlined,
                    unPressedIcon: Icons.favorite_outline,
                    tooltip: loc.like,
                  ),
                // 🚫 Not Favor（登入即可）
                if (widget.onDislike != null)
                  PressButton(
                    isPress: widget.eventViewModel.isDislike,
                    color: Colors.grey,
                    onPressed: widget.onDislike,
                    pressedIcon: Icons.sentiment_neutral_sharp,
                    unPressedIcon: Icons.sentiment_dissatisfied_outlined,
                    tooltip: loc.dislike,
                  ),
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
