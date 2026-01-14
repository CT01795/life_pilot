import 'dart:async';

import 'package:flutter/material.dart';
import 'package:life_pilot/models/event/model_event_weather.dart';
import 'package:life_pilot/services/service_weather.dart';

class ControllerPageEventWeather extends ChangeNotifier {
  final ServiceWeather serviceWeather;

  List<EventWeather> forecast = [];
  bool loading = false;
  bool disposed = false;

  ControllerPageEventWeather(this.serviceWeather);
  
  Future<void> load1({
    required String locationDisplay, required DateTime? startDate
  }) async {
    if (loading || locationDisplay.isEmpty || (startDate != null && (DateTime.now().add(Duration(days: 7))).isBefore(startDate))) return;

    loading = true;
    if (!disposed) notifyListeners();

    forecast = await serviceWeather.get3DayWeather(
      locationDisplay: locationDisplay,
      startDate: startDate
    );

    loading = false;
    if (!disposed) notifyListeners();
  }

  @override
  void dispose() {
    disposed = true;
    super.dispose();
  }
}