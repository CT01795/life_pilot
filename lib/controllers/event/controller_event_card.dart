import 'dart:async';

import 'package:flutter/material.dart';
import 'package:life_pilot/controllers/auth/controller_auth.dart';
import 'package:life_pilot/core/const.dart';
import 'package:life_pilot/models/event/model_event_view.dart';
import 'package:life_pilot/models/event/model_event_weather.dart';
import 'package:life_pilot/services/event/service_event.dart';
import 'package:life_pilot/services/service_weather.dart';

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
    await serviceEvent.incrementEventCounter(
      eventId: event.id,
      eventName: event.name,
      column: 'page_views',
      account: controllerAuth.currentAccount ?? AuthConstants.guest,
    );
  }

  Future<void> onOpenMap(EventViewModel event) async {
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
