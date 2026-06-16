import 'package:flutter/material.dart';
import 'package:life_pilot/stock/model_stock.dart';
import 'package:life_pilot/stock/service_stock.dart';
import 'package:life_pilot/utils/logger.dart';

class ControllerStock extends ChangeNotifier {
  final ServiceStock service;

  List<ModelStock> stocks = [];
  bool loading = true;

  ControllerStock(this.service);

  Future<void> load() async {
    loading = true;
    notifyListeners();

    // 1️⃣ 先顯示現有資料（快速）
    stocks = await service.getSimpleStrategySupabase("From Supabase 1");
    loading = false;
    notifyListeners();

    // 1️⃣ 先顯示現有資料（快速）
     stocks = await service.getSimpleStrategy("Updating 2");
     loading = false;
     notifyListeners();
     
     try{
      // 2️⃣ 背景更新資料（不阻塞 UI）
      await service.loadRawData();
    } catch (ex) {
      logger.e(ex);
    }
    // 3️⃣ 更新完成後，再抓一次（刷新畫面🔥）
    stocks = await service.getSimpleStrategy("Updated 3");
    loading = false;
    notifyListeners();
  }
}
