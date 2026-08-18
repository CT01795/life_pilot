import 'package:flutter/material.dart';
import 'package:life_pilot/stock/model_stock.dart';
import 'package:life_pilot/stock/service_stock.dart';
import 'package:life_pilot/utils/logger.dart';

enum StockUpdateStatus { idle, updating, succeeded, failed }

class ControllerStock extends ChangeNotifier {
  final ServiceStock service;

  List<ModelStock> stocks = [];
  List<ModelFuture> futures = [];
  List<ModelInstitutional> institutionals = [];
  List<ModelInstitutional> foreignBuyTop30 = [];
  List<ModelInstitutional> foreignSellTop30 = [];
  bool loading = true;
  bool loadFailed = false;
  StockUpdateStatus updateStatus = StockUpdateStatus.idle;

  ControllerStock(this.service);

  Future<void> load() async {
    loading = true;
    loadFailed = false;
    updateStatus = StockUpdateStatus.idle;
    notifyListeners();

    var initialSourceLoaded = false;

    // 1️⃣ 先顯示現有資料（快速）
    try {
      await _useStocksIfAvailable(
        await service.getSimpleStrategySupabase("From Supabase 1"),
      );
      initialSourceLoaded = true;
      loading = false;
      notifyListeners();
    } catch (ex) {
      logger.e(ex);
    }

    // 1️⃣ 先顯示現有資料（快速）
    try {
      await _useStocksIfAvailable(
        await service.getSimpleStrategy("Updating 2"),
      );
      initialSourceLoaded = true;
    } catch (ex) {
      logger.e(ex);
    }

    loading = false;
    if (!initialSourceLoaded && stocks.isEmpty) {
      loadFailed = true;
      notifyListeners();
      return;
    }

    updateStatus = StockUpdateStatus.updating;
    notifyListeners();

    try {
      // 2️⃣ 背景更新資料（不阻塞 UI）
      await service.loadRawData();
      await _useStocksIfAvailable(
        await service.getSimpleStrategy("Updated 3"),
      );
    } catch (ex) {
      logger.e(ex);
      updateStatus = StockUpdateStatus.failed;
      notifyListeners();
      return;
    }
    // 3️⃣ 更新完成後，再抓一次（刷新畫面🔥）
    updateStatus = StockUpdateStatus.succeeded;
    notifyListeners();
  }

  Future<void> _useStocksIfAvailable(List<ModelStock> availableStocks) async {
    if (availableStocks.isEmpty) return;

    stocks = availableStocks;
    await buildDashboard(stocks.first.date);
  }

  Future<void> buildDashboard(DateTime? date) async {
    date = date ?? await service.getLatestDate();
    if (date == null) {
      return;
    }
    // ==========
    // 外資買超 Top30
    // ==========
    institutionals = await service.selectStockInstitutional(date);
    foreignBuyTop30 = [...institutionals];

    foreignBuyTop30.sort(
      (a, b) => b.foreignDiff.compareTo(
        a.foreignDiff,
      ),
    );

    foreignBuyTop30 = foreignBuyTop30
        .where((e) => e.foreignDiff > 0)
        .toList(); //.take(30).toList();

    // ==========
    // 外資賣超 Top30
    // ==========
    foreignSellTop30 = [...institutionals];

    foreignSellTop30.sort(
      (a, b) => a.foreignDiff.compareTo(
        b.foreignDiff,
      ),
    );

    foreignSellTop30 = foreignSellTop30
        .where((e) => e.foreignDiff < 0)
        .toList(); //.take(30).toList();

    // ==========
    // 期貨未平倉
    // ==========

    try {
      futures = await service.selectFutures(date);
    } catch (_) {}
  }
}
