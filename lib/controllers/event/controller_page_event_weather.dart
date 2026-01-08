import 'dart:async';

import 'package:flutter/material.dart';
import 'package:life_pilot/models/event/model_event_weather.dart';
import 'package:life_pilot/services/service_weather.dart';

class ControllerPageEventWeather extends ChangeNotifier {
  final ServiceWeather serviceWeather;

  List<EventWeather> forecast = [];
  bool loading = false;

  ControllerPageEventWeather(this.serviceWeather);
  
  Future<void> load({
    required String locationDisplay,
  }) async {
    loading = true;
    notifyListeners();

    forecast = await serviceWeather.get3DayWeather(
      locationDisplay: locationDisplay,
    );

    loading = false;
    notifyListeners();
  }
}