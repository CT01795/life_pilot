// lib/views/widgets/event/event_card_widgets.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:life_pilot/controllers/event/controller_event.dart';
import 'package:life_pilot/controllers/event/controller_page_event_weather.dart';
import 'package:life_pilot/core/app_navigator.dart';
import 'package:life_pilot/core/const.dart' as globals;
import 'package:life_pilot/core/const.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/views/widgets/event/widgets_event_sub_card.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

class WidgetsEventCard extends StatefulWidget {
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

  @override
  State<WidgetsEventCard> createState() => _WidgetsEventCardState();
}

class _WidgetsEventCardState extends State<WidgetsEventCard> {
  String? weatherApiKey;

  @override
  void initState() {
    super.initState();
    weatherApiKey = globals.weatherApiKey;
    context.read<ControllerPageEventWeather>().load(
          locationDisplay: widget.eventViewModel.locationDisplay,
        );
  }

  @override
  Widget build(BuildContext context) {
    final weatherCtrl = context.watch<ControllerPageEventWeather>();
    final now = DateTime.now();
    final tmpDate = formatDateRange(now, widget.eventViewModel.dateRange);
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
          if (showWeatherIcon && todayWeather != null)
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
                  '${todayWeather..main} ${todayWeather..temp.toStringAsFixed(1)}°C',
              onPressed: () async {
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
                              subtitle: Text(
                                  '${w.description}\nTemperature: ${w.temp.toStringAsFixed(1)}°C\nMin:${w.tempMin.toStringAsFixed(1)}°C~Max:${w.tempMax.toStringAsFixed(1)}°C\n'),
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
            overflow: TextOverflow.ellipsis, // 防止文字過長
            softWrap: true,
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
            WidgetsEventCard.tags(typeList: widget.eventViewModel.tags),
          if (widget.eventViewModel.hasLocation)
            InkWell(
              onTap: () async {
                final query =
                    Uri.encodeComponent(widget.eventViewModel.locationDisplay);

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
              child: Text(
                widget.eventViewModel.locationDisplay,
                style: const TextStyle(
                  color: Colors.blue,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          if (widget.eventViewModel.masterUrl?.isNotEmpty == true)
            WidgetsEventCard.link(
                loc: loc, url: widget.eventViewModel.masterUrl!),
          if (widget.eventViewModel.description.isNotEmpty)
            Text(widget.eventViewModel.description),
          if (widget.showSubEvents)
            ...widget.eventViewModel.subEvents
                .map((sub) => WidgetsEventSubCard(event: sub)),
        ],
      ),
    );

    final container = widget.tableName != TableNames.calendarEvents
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
      onTap: widget.eventViewModel.subEvents.isNotEmpty ? widget.onTap : null,
      child: Stack(
        children: [
          container,
          if (widget.eventViewModel.canDelete && widget.onDelete != null)
            PositionedDirectional(
              end: Gaps.w24.width,
              bottom: Gaps.h8.height,
              child: IconButton(
                icon: const Icon(Icons.delete, color: Colors.redAccent),
                tooltip: loc.delete,
                onPressed: widget.onDelete,
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
