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

    for (int i = 1; i <= 15; i++) {
      await service.loadRawDataTWSE(
        today.subtract(Duration(days: i)),
      );
      await service.loadRawDataOTC(
        today.subtract(Duration(days: i)),
      );
    }
    await service.quantitativeCalculation(today.subtract(Duration(days: 1)));

    stocks = await service.getSimpleStrategy();

    loading = false;
    notifyListeners();
  }
}
