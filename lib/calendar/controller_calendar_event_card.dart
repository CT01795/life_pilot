import 'dart:async';

import 'package:flutter/material.dart';
import 'package:life_pilot/event/model_event_item.dart';
import 'package:life_pilot/utils/model_event_weather.dart';
import 'package:life_pilot/event/service_event.dart';
import 'package:life_pilot/utils/service/service_weather.dart';

class ControllerCalendarEventCard extends ChangeNotifier {
  final ServiceWeather serviceWeather;
  final ServiceEvent serviceEvent;
  final String currentAccount;

  List<EventWeather> forecast = [];
  bool loading = false;
  bool disposed = false;
  bool _isLoaded = false;

  ControllerCalendarEventCard({
    required this.serviceEvent,
    required this.serviceWeather,
    required this.currentAccount,
  });

  Future<void> loadWeather(
      {required String locationDisplay, required DateTime? startDate, required DateTime? endDate, required String tableName}) async {
    if (_isLoaded) return; // 已經載入過就跳過
    _isLoaded = true;
    final today = DateTime.now();
    if (loading ||
        locationDisplay.isEmpty ||
        (startDate != null &&
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
    await serviceEvent.incrementEventCounter(
      eventId: event.id,
      eventName: event.name,
      column: 'page_views',
      account: currentAccount,
    );
  }

  Future<void> onOpenMap(EventViewModel event) async {
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
