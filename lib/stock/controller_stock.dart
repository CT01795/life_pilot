import 'package:flutter/material.dart';
import 'package:life_pilot/stock/model_stock.dart';
import 'package:life_pilot/stock/service_stock.dart';

class ControllerStock extends ChangeNotifier {
  final ServiceStock service;

  List<ModelStock> stocks = [];
  bool loading = true;

  ControllerStock(this.service);

  Future<void> load() async {
    loading = true;
    notifyListeners();

    DateTime today = DateUtils.dateOnly(DateTime.now());

    for (int i = 1; i <= 30; i++) {
      await service.loadRawDataDailyPrices(
        today.subtract(Duration(days: i)),
      );
    }

    stocks = await service.getStatData();

    loading = false;
    notifyListeners();
  }
}