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

  final Set<String> _loadingIds  = {};
  final Map<String, List<EventWeather>> _forecastCache = {};

  // ------------------ Public ------------------

  List<EventWeather>? getForecast(String eventId) {
    return _forecastCache[eventId];
  }

  // 取得天氣預報（緩存）
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

    try {
      final data = await serviceWeather.getWeather(
        locationDisplay: event.locationDisplay, startDate: event.startDate);

      _forecastCache[event.id] = data;
    } catch (e, st) {
      logger.e('loadWeather failed for ${event.id}: $e\n$st');
      _forecastCache[event.id] = [];
    } finally {
      _loadingIds.remove(event.id);
      if (!disposed) notifyListeners();
    }
  }

  // 開啟活動連結
  Future<void> onOpenLink(EventViewModel event) async {
    if (event.masterUrl == null || event.masterUrl!.isEmpty) return;
    await _launchUrl(
      Uri.parse(event.masterUrl!),
      event,
      column: 'page_views',
    );
  }

  // 開啟地圖導航
  Future<void> onOpenMap(EventViewModel event) async {
    if (event.locationDisplay.isEmpty) return;
    final query =
        Uri.encodeComponent(event.locationDisplay);

    // Google Maps 網頁導航 URL
    final googleMapsUrl = Uri.parse(
        'https://www.google.com/maps/dir/?api=1&destination=$query');
    await _launchUrl(
      googleMapsUrl,
      event,
      column: 'card_clicks',
    );
  }

  // ------------------ Private ------------------

  /// 統一處理 URL 開啟與事件計數
  Future<void> _launchUrl(Uri uri, EventViewModel event,
      {required String column}) async {
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      await _incrementCounter(event, column);
    } catch (e) {
      logger.e('Failed to launch URL for ${event.id}: $e');
    }
  }

  /// 統一事件計數
  Future<void> _incrementCounter(EventViewModel event, String column) async {
    try {
      await serviceEvent.incrementEventCounter(
        eventId: event.id,
        eventName: event.name,
        column: column,
        account: currentAccount,
      );
    } catch (e) {
      logger.e('Failed to increment counter for ${event.id} ($column): $e');
    }
  }
  
  @override
  void dispose() {
    disposed = true;
    super.dispose();
  }
}
