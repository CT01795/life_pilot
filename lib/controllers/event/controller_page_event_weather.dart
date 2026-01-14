import 'dart:async';

import 'package:flutter/material.dart';
import 'package:life_pilot/core/const.dart';
import 'package:life_pilot/models/event/model_event_weather.dart';
import 'package:life_pilot/services/service_weather.dart';

class ControllerPageEventWeather extends ChangeNotifier {
  final ServiceWeather serviceWeather;

  List<EventWeather> forecast = [];
  bool loading = false;
  bool disposed = false;

  ControllerPageEventWeather(this.serviceWeather);

  Future<void> loadWeather(
      {required String locationDisplay, required DateTime? startDate, required String tableName}) async {
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

  @override
  void dispose() {
    disposed = true;
    super.dispose();
  }
}
