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

    // 1️⃣ 先顯示現有資料（快速）
    stocks = await service.getSimpleStrategy();
    loading = false;
    notifyListeners();

    // 2️⃣ 背景更新資料（不阻塞 UI）
    await service.loadRawData();

    // 3️⃣ 更新完成後，再抓一次（刷新畫面🔥）
    stocks = await service.getSimpleStrategy();
    notifyListeners();
  }
}
