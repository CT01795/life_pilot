import 'dart:async';

import 'package:flutter/material.dart';
import 'package:life_pilot/event/model_event_item.dart';
import 'package:life_pilot/utils/date_time.dart';
import 'package:life_pilot/utils/logger.dart';
import 'package:life_pilot/utils/model_event_weather.dart';
import 'package:life_pilot/event/service_event.dart';
import 'package:life_pilot/utils/service/service_weather.dart';
import 'package:url_launcher/url_launcher.dart';

class ControllerCalendarEventCard extends ChangeNotifier {
  final ServiceWeather serviceWeather;
  final ServiceEvent serviceEvent;
  final String currentAccount;

  bool disposed = false;

  ControllerCalendarEventCard({
    required this.serviceEvent,
    required this.serviceWeather,
    required this.currentAccount,
  });

  List<EventWeather>? getForecast(String eventId) {
    return _forecastCache[eventId];
  }

  final Set<String> _loadingIds  = {};
  final Map<String, List<EventWeather>> _forecastCache = {};
  Future<void> loadWeather(EventViewModel event) async {
    if (!event.hasLocation) return;
    if (_forecastCache.containsKey(event.id)) return;
    if (_loadingIds .contains(event.id)) return;

    final today = DateTimeFormatter.dateOnly(DateTime.now());
    if (event.locationDisplay.isEmpty ||
        (event.startDate != null &&
            ((today.add(Duration(days: 7))).isBefore(event.startDate!) ||
                today.isAfter(event.startDate!)))) {
      return;
    }

    _loadingIds .add(event.id);

    final data = await serviceWeather.getWeather(
        locationDisplay: event.locationDisplay, startDate: event.startDate);

    _forecastCache[event.id] = data;
    _loadingIds .remove(event.id);
    if (!disposed) notifyListeners();
  }

  Future<void> onOpenLink(EventViewModel event, String url) async {
    final uri = Uri.parse(url);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
    await serviceEvent.incrementEventCounter(
      eventId: event.id,
      eventName: event.name,
      column: 'page_views',
      account: currentAccount,
    );
  }

  Future<void> onOpenMap(EventViewModel event) async {
    final query =
        Uri.encodeComponent(event.locationDisplay);

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
      logger.e('Can\'t open map：$e');
    }
    await serviceEvent.incrementEventCounter(
      eventId: event.id,
      eventName: event.name,
      column: 'card_clicks',
      account: currentAccount,
    );
  }
  
  @override
  void dispose() {
    disposed = true;
    super.dispose();
  }
}
