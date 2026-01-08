// lib/views/widgets/event/event_card_widgets.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:life_pilot/controllers/event/controller_event.dart';
import 'package:life_pilot/controllers/event/controller_page_event_weather.dart';
import 'package:life_pilot/core/app_navigator.dart';
import 'package:life_pilot/core/const.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/services/service_weather.dart';
import 'package:life_pilot/views/widgets/event/widgets_event_sub_card.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

class WidgetsEventCard extends StatelessWidget {
  final EventViewModel eventViewModel;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;
  final Widget? trailing;
  final String tableName;
  final bool showSubEvents;

  const WidgetsEventCard({
    super.key,
    required this.eventViewModel,
    required this.tableName,
    this.onTap,
    this.onDelete,
    this.trailing,
    this.showSubEvents = true,
  });

  @override
  Widget build(BuildContext context) {
    final serviceWeather = context.read<ServiceWeather>();
    return ChangeNotifierProvider(
      create: (_) {
        final ctrl = ControllerPageEventWeather(serviceWeather);

        // ✅ 延遲呼叫，避免在 build 階段或 widget 被移除時觸發
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!ctrl.disposed) {
            ctrl.load(locationDisplay: eventViewModel.locationDisplay);
          }
        });

        return ctrl;
      },
      child: _WidgetsEventCardBody(
        eventViewModel: eventViewModel,
        tableName: tableName,
        onTap: onTap,
        onDelete: onDelete,
        trailing: trailing,
        showSubEvents: showSubEvents,
      ),
    );
  }

  static Widget link({
    required AppLocalizations loc,
    required String url,
  }) {
    return InkWell(
      onTap: () async {
        final uri = Uri.parse(url);
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        AppNavigator.showSnackBar(
            '${loc.url}: ${url.substring(0, url.length > 10 ? 10 : url.length)}');
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
  final Widget? trailing;
  final String tableName;
  final bool showSubEvents;

  const _WidgetsEventCardBody({
    required this.eventViewModel,
    required this.tableName,
    this.onTap,
    this.onDelete,
    this.trailing,
    this.showSubEvents = true,
  });

  @override
  Widget build(BuildContext context) {
    final weatherCtrl = context.watch<ControllerPageEventWeather>();
    final now = DateTime.now();
    final tmpDate = formatDateRange(now, eventViewModel.dateRange);
    final eventDate =
        DateTime.tryParse(tmpDate ?? '') ?? now.add(const Duration(days: 1));

    final showWeatherIcon =
        weatherCtrl.forecast.isNotEmpty && eventDate.isAfter(now);

    final todayWeather =
        weatherCtrl.forecast.isNotEmpty ? weatherCtrl.forecast.first : null;

    final loc = AppLocalizations.of(context)!;
    Widget buildHeader() {
      return Row(
        children: [
          // 天氣 Icon
          if (showWeatherIcon && todayWeather != null && context.mounted)
            IconButton(
              icon: Container(
                width: 42, // 可調整大小
                height: 42,
                decoration:
                    todayWeather.main == 'Clouds' || todayWeather.main == 'Rain'
                        ? BoxDecoration(
                            color: Colors.grey.shade300, // 舒服的淺灰色背景
                            shape: BoxShape.circle,
                          )
                        : null, // 其他天氣不加背景
                padding: const EdgeInsets.all(1), // 內邊距
                child: Image.network(
                  'https://openweathermap.org/img/wn/${todayWeather.icon}@2x.png',
                  width: 40,
                  height: 40,
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
                          children: weatherCtrl.forecast.map((w) {
                            String tmp =
                                '${w.description}\nTemperature: ${w.temp.toStringAsFixed(1)}°C';
                            if (w.temp.toStringAsFixed(1) !=
                                w.tempMin.toStringAsFixed(1)) {
                              tmp = '$tmp\nMin:${w.tempMin.toStringAsFixed(1)}°C';
                            }
                            if (w.temp.toStringAsFixed(1) !=
                                w.tempMax.toStringAsFixed(1)) {
                              tmp = '$tmp~Max:${w.tempMax.toStringAsFixed(1)}°C';
                            }
                            tmp = '$tmp\n';
                            return ListTile(
                              leading: Container(
                                width: 42, // 可調整大小
                                height: 42,
                                decoration: w.main == 'Clouds' ||
                                        w.main == 'Rain'
                                    ? BoxDecoration(
                                        color: Colors.grey.shade300, // 舒服的淺灰色背景
                                        shape: BoxShape.circle,
                                      )
                                    : null, // 其他天氣不加背景
                                padding: const EdgeInsets.all(1), // 內邊距
                                child: Image.network(
                                  'https://openweathermap.org/img/wn/${w.icon}.png',
                                  width: 40,
                                  height: 40,
                                ),
                              ),
                              title: Text(
                                  '${DateFormat('M/d H點').format(w.date)} ${w.main}'),
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
              child: Text(eventViewModel.name,
            style: const TextStyle(fontWeight: FontWeight.bold),
            overflow: TextOverflow.ellipsis, // 防止文字過長
            softWrap: true,
          )),
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
              },
              child: Text(eventViewModel.locationDisplay,
                style: const TextStyle(
                  color: Colors.blue,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          if (eventViewModel.masterUrl?.isNotEmpty == true)
            WidgetsEventCard.link(
                loc: loc, url: eventViewModel.masterUrl!),
          if (eventViewModel.description.isNotEmpty)
            Text(eventViewModel.description),
          if (showSubEvents)
            ...eventViewModel.subEvents
                .map((sub) => WidgetsEventSubCard(event: sub)),
        ],
      ),
    );

    final container = tableName != TableNames.calendarEvents
        ? Card(
            margin: Insets.h8v16,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            color: Colors.grey.shade100,
            elevation: 4,
            child: content,
          )
        : Container(
            margin: Insets.h8v16,
            child: content,
          );

    return GestureDetector(
      onTap: eventViewModel.subEvents.isNotEmpty ? onTap : null,
      child: Stack(
        children: [
          container,
          if (eventViewModel.canDelete && onDelete != null)
            PositionedDirectional(
              end: Gaps.w24.width,
              bottom: Gaps.h8.height,
              child: IconButton(
                icon: const Icon(Icons.delete, color: Colors.redAccent),
                tooltip: loc.delete,
                onPressed: onDelete,
              ),
            ),
        ],
      ),
    );
  }

  String? formatDateRange(DateTime now, String dateRange) {
    String tmpDate = dateRange.split(" ")[0];
    if (tmpDate.length < 10) {
      tmpDate = '${now.year}/$tmpDate';
    }
    List<String> tmpDateElement = tmpDate.split("/");
    if (tmpDateElement.length < 3) {
      return null;
    } else {
      return '${tmpDateElement[0]}-${tmpDateElement[1].padLeft(2, '0')}-${tmpDateElement[2].padLeft(2, '0')}';
    }
  }
}
