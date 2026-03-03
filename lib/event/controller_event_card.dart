import 'dart:async';

import 'package:flutter/material.dart';
import 'package:life_pilot/auth/controller_auth.dart';
import 'package:life_pilot/event/model_event_item.dart';
import 'package:life_pilot/utils/const.dart';
import 'package:life_pilot/event/service_event.dart';
import 'package:life_pilot/utils/logger.dart';
import 'package:life_pilot/utils/model_event_weather.dart';
import 'package:life_pilot/utils/service/service_weather.dart';
import 'package:url_launcher/url_launcher.dart';

class ControllerEventCard extends ChangeNotifier {
  final ServiceWeather serviceWeather;
  final ServiceEvent serviceEvent;
  final ControllerAuth controllerAuth;

  List<EventWeather> forecast = [];
  bool loading = false;
  bool disposed = false;
  bool _isLoaded = false;

  ControllerEventCard({
    required this.serviceEvent,
    required this.serviceWeather,
    required this.controllerAuth,
  });

  Future<void> loadWeather(
      {required String locationDisplay, required DateTime? startDate, required DateTime? endDate, required String tableName}) async {
    if (_isLoaded) return; // 已經載入過就跳過
    _isLoaded = true;
    final today = DateTime.now();
    if (loading ||
        locationDisplay.isEmpty ||
        (tableName != TableNames.recommendedAttractions && startDate != null &&
            ((today.add(Duration(days: 7))).isBefore(startDate) ||
                today.isAfter(startDate)))) {
      return;
    }

    loading = true;
    if (!disposed) notifyListeners();

    forecast = await serviceWeather.getWeather(
        locationDisplay: locationDisplay, startDate: startDate);

    loading = false;
    if (!disposed) notifyListeners();
  }

  Future<void> onOpenLink(EventViewModel event) async {
    final uri = Uri.parse(event.masterUrl!);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
    await serviceEvent.incrementEventCounter(
      eventId: event.id,
      eventName: event.name,
      column: 'page_views',
      account: controllerAuth.currentAccount ?? AuthConstants.guest,
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
      account: controllerAuth.currentAccount ?? AuthConstants.guest,
    );
  }
  
  @override
  void dispose() {
    disposed = true;
    super.dispose();
  }
}
