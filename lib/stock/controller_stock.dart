import 'package:flutter/material.dart';
import 'package:life_pilot/stock/model_stock.dart';
import 'package:life_pilot/stock/service_stock.dart';
import 'package:life_pilot/utils/logger.dart';

class ControllerStock extends ChangeNotifier {
  final ServiceStock service;

  List<ModelStock> stocks = [];
  List<ModelFuture> futures = [];
  List<ModelInstitutional> institutionals = [];
  List<ModelInstitutional> foreignBuyTop15 = [];
  List<ModelInstitutional> foreignSellTop15 = [];
  ModelFuture? foreignFuture;
  ModelFuture? trustFuture;
  ModelFuture? dealerFuture;
  bool loading = true;

  ControllerStock(this.service);

  Future<void> load() async {
    loading = true;
    notifyListeners();

    // 1️⃣ 先顯示現有資料（快速）
    stocks = await service.getSimpleStrategySupabase("From Supabase 1");
    await buildDashboard(stocks[0].date);
    loading = false;
    notifyListeners();

    // 1️⃣ 先顯示現有資料（快速）
    stocks = await service.getSimpleStrategy("Updating 2");
    await buildDashboard(stocks[0].date);
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
    await buildDashboard(stocks[0].date);
    loading = false;
    notifyListeners();
  }

  Future<void> buildDashboard(DateTime? date) async {
    date = date ?? await service.getLatestDate();
    if (date == null) {
      return;
    }
    // ==========
    // 外資買超 Top15
    // ==========
    institutionals = await service.selectStockInstitutional(date);
    foreignBuyTop15 = [...institutionals];

    foreignBuyTop15.sort(
      (a, b) =>
          b.foreignDiff.compareTo(a.foreignDiff,),
    );

    foreignBuyTop15 =
        foreignBuyTop15.take(15).toList();

    // ==========
    // 外資賣超 Top15
    // ==========
    foreignSellTop15 = [...institutionals];

    foreignSellTop15.sort(
      (a, b) =>
          a.foreignDiff.compareTo(b.foreignDiff,),
    );

    foreignSellTop15 =
        foreignSellTop15.take(15).toList();

    // ==========
    // 期貨未平倉
    // ==========

    try {
      futures = await service.selectFutures(date);
      foreignFuture =
          futures.firstWhere(
        (e) =>
            e.productName!.contains(
                '臺股期貨') &&
            e.identityType!.contains(
                '外資'),
      );
    } catch (_) {}

    try {
      trustFuture =
          futures.firstWhere(
        (e) =>
            e.productName!.contains(
                '臺股期貨') &&
            e.identityType!.contains(
                '投信'),
      );
    } catch (_) {}

    try {
      dealerFuture =
          futures.firstWhere(
        (e) =>
            e.productName!.contains(
                '臺股期貨') &&
            e.identityType!.contains(
                '自營商'),
      );
    } catch (_) {}
  }
}


