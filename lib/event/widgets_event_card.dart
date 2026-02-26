// lib/views/widgets/event/event_card_widgets.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:life_pilot/auth/controller_auth.dart';
import 'package:life_pilot/event/controller_event.dart';
import 'package:life_pilot/event/controller_event_card.dart';
import 'package:life_pilot/utils/app_navigator.dart';
import 'package:life_pilot/utils/const.dart';
import 'package:life_pilot/utils/date_time.dart';
import 'package:life_pilot/utils/graph.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/event/model_event_item.dart';
import 'package:life_pilot/event/service_event.dart';
import 'package:life_pilot/utils/service/service_weather.dart';
import 'package:life_pilot/event/widgets_event_sub_card.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

class WidgetsEventCard extends StatelessWidget {
  final EventViewModel eventViewModel;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;
  final VoidCallback? onLike;
  final VoidCallback? onDislike;
  final VoidCallback? onAccounting;
  final Widget? trailing;
  final String tableName;
  final bool showSubEvents;

  const WidgetsEventCard({
    super.key,
    required this.eventViewModel,
    required this.tableName,
    this.onTap,
    this.onDelete,
    this.onLike,
    this.onDislike,
    this.onAccounting,
    this.trailing,
    this.showSubEvents = true,
  });

  @override
  Widget build(BuildContext context) {
    final serviceWeather = context.read<ServiceWeather>();
    final serviceEvent = context.read<ServiceEvent>();
    final controllerAuth = context.read<ControllerAuth>();
    return ChangeNotifierProvider(
      create: (_) => ControllerEventCard(
        serviceWeather: serviceWeather,
        serviceEvent: serviceEvent,
        controllerAuth: controllerAuth,
      )..loadWeather(
          locationDisplay: eventViewModel.locationDisplay,
          startDate: eventViewModel.startDate,
          endDate: eventViewModel.endDate,
          tableName: tableName,
        ),
      child: _WidgetsEventCardBody(
        eventViewModel: eventViewModel,
        tableName: tableName,
        onTap: onTap,
        onDelete: onDelete,
        onLike: onLike,
        onDislike: onDislike,
        onAccounting: onAccounting,
        trailing: trailing,
        showSubEvents: showSubEvents,
      ),
    );
  }

  static Widget link(
      {required BuildContext context,
      required AppLocalizations loc,
      required String url,
      required EventViewModel eventViewModel}) {
    return InkWell(
      onTap: () async {
        final uri = Uri.parse(url);
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        AppNavigator.showSnackBar(
            '${loc.url}: ${url.substring(0, url.length > 10 ? 10 : url.length)}');
        // 🔹 呼叫 function 更新資料庫
        final controllerEventCard = context.read<ControllerEventCard>();
        await controllerEventCard.onOpenLink(eventViewModel);
        final controllerEvent = context.read<ControllerEvent>();
        if (controllerEvent.tableName == TableNames.recommendedEvents) {
          controllerEvent.loadEvents();
        }
      },
      child: Text(
        loc.clickHereToSeeMore,
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

class _WidgetsEventCardBody extends StatelessWidget {
  final EventViewModel eventViewModel;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;
  final VoidCallback? onLike;
  final VoidCallback? onDislike;
  final VoidCallback? onAccounting;
  final Widget? trailing;
  final String tableName;
  final bool showSubEvents;

  const _WidgetsEventCardBody({
    required this.eventViewModel,
    required this.tableName,
    this.onTap,
    this.onDelete,
    this.onLike,
    this.onDislike,
    this.onAccounting,
    this.trailing,
    this.showSubEvents = true,
  });

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<ControllerEventCard>();
    final now = DateTime.now();
    final tmpDate = DateTimeFormatter.formatDateRange(now, eventViewModel.dateRange);
    final eventDate =
        DateTime.tryParse(tmpDate ?? '') ?? now.add(const Duration(days: 1));

    final showWeatherIcon = ctrl.forecast.isNotEmpty && eventDate.isAfter(now);

    final todayWeather = ctrl.forecast.isNotEmpty ? ctrl.forecast.first : null;

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
                  future: assetExists(
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
                          children: ctrl.forecast.map((w) {
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
                                  future: assetExists(
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
              eventViewModel.name,
              style: const TextStyle(fontWeight: FontWeight.bold),
              softWrap: true, // 允許換行
              overflow: TextOverflow.visible, // 文字超過不截斷
              //overflow: TextOverflow.ellipsis, // 防止文字過長
            )
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
      padding: Insets.all4,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          buildHeader(),
          if (eventViewModel.dateRange.isNotEmpty)
            Text(eventViewModel.dateRange),
          if (eventViewModel.tags.isNotEmpty)
            WidgetsEventCard.tags(typeList: eventViewModel.tags),
          if (eventViewModel.hasLocation)
            InkWell(
              onTap: () async {
                if (!context.mounted) return;
                final query =
                    Uri.encodeComponent(eventViewModel.locationDisplay);

                // Google Maps 網頁導航 URL
                final googleMapsUrl = Uri.parse(
                    'https://www.google.com/maps/dir/?api=1&destination=$query');

                try {
                  // LaunchMode.externalApplication 確保在手機會跳出 App 或瀏覽器
                  await launchUrl(
                    googleMapsUrl,
                    mode: LaunchMode.externalApplication,
                  );
                } catch (e) {
                  // 若有錯誤顯示提示
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Can\'t open map：$e')),
                  );
                }
                // 🔹 呼叫 function 更新資料庫
                await ctrl.onOpenMap(eventViewModel);
                final controllerEvent = context.read<ControllerEvent>();
                if (controllerEvent.tableName == TableNames.recommendedEvents) {
                  controllerEvent.loadEvents();
                }
              },
              child: Text(
                eventViewModel.locationDisplay,
                style: const TextStyle(
                  color: Colors.blue,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          if (eventViewModel.masterUrl?.isNotEmpty == true)
            WidgetsEventCard.link(
                context: context,
                loc: loc,
                url: eventViewModel.masterUrl!,
                eventViewModel: eventViewModel),
          if (eventViewModel.description.isNotEmpty)
            Text(eventViewModel.description),
          if (showSubEvents)
            ...eventViewModel.subEvents
                .map((sub) => WidgetsEventSubCard(event: sub)),
        ],
      ),
    );

    final container = Card(
            margin: Insets.h8v16,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            color: Colors.grey.shade100,
            elevation: 4,
            child: content,
          );

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
                // 👍 Favor（登入即可）
                if (onLike != null)
                  IconButton(
                    icon: Icon(
                      eventViewModel.isLike == true
                          ? Icons.favorite_outlined
                          : Icons.favorite_outline,
                      color: Colors.pinkAccent,
                    ),
                    tooltip: loc.like,
                    onPressed: onLike,
                  ),

                // 🚫 Not Favor（登入即可）
                if (onDislike != null)
                  IconButton(
                    icon: Icon(
                      eventViewModel.isDislike == true
                          ? Icons.sentiment_neutral_sharp
                          : Icons.sentiment_dissatisfied_outlined,
                      color: Colors.grey,
                    ),
                    tooltip: loc.dislike,
                    onPressed: onDislike,
                  ),
                if (onAccounting != null)
                  IconButton(
                    icon: Icon(Icons.currency_exchange),
                    tooltip: loc.accountRecords,
                    onPressed: onAccounting,
                  ),
                // 🗑 Delete（只有 canDelete）
                if (eventViewModel.canDelete && onDelete != null)
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.redAccent),
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
