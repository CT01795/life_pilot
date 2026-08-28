import 'package:life_pilot/stock/model_stock.dart';
import 'package:life_pilot/stock/service_stock.dart';
import 'package:life_pilot/utils/logger.dart';
import 'package:life_pilot/utils/safe_change_notifier.dart';

enum StockUpdateStatus { idle, updating, succeeded, failed }

class ControllerStock extends SafeChangeNotifier {
  final ServiceStock service;

  List<ModelStock> stocks = [];
  List<ModelFuture> futures = [];
  List<ModelInstitutional> institutionals = [];
  List<ModelInstitutional> foreignBuyTop30 = [];
  List<ModelInstitutional> foreignSellTop30 = [];
  bool loading = true;
  bool loadFailed = false;
  StockUpdateStatus updateStatus = StockUpdateStatus.idle;
  bool _isDisposed = false;

  ControllerStock(this.service);

  Future<void> load() async {
    if (_isDisposed) return;
    loading = true;
    loadFailed = false;
    updateStatus = StockUpdateStatus.idle;
    _notifyListenersIfActive();

    var initialSourceLoaded = false;

    // 1️⃣ 先顯示現有資料（快速）
    try {
      await _useStocksIfAvailable(
        await service.getSimpleStrategySupabase("From Supabase 1"),
      );
      if (_isDisposed) return;
      initialSourceLoaded = true;
      loading = false;
      _notifyListenersIfActive();
    } catch (ex) {
      logger.e(ex);
    }
    if (_isDisposed) return;

    // 1️⃣ 先顯示現有資料（快速）
    try {
      await _useStocksIfAvailable(
        await service.getSimpleStrategy("Updating 2"),
      );
      if (_isDisposed) return;
      initialSourceLoaded = true;
    } catch (ex) {
      logger.e(ex);
    }
    if (_isDisposed) return;

    loading = false;
    if (!initialSourceLoaded && stocks.isEmpty) {
      loadFailed = true;
      _notifyListenersIfActive();
      return;
    }

    updateStatus = StockUpdateStatus.updating;
    _notifyListenersIfActive();

    try {
      // 2️⃣ 背景更新資料（不阻塞 UI）
      await service.loadRawData();
      if (_isDisposed) return;
      await _useStocksIfAvailable(
        await service.getSimpleStrategy("Updated 3"),
      );
      if (_isDisposed) return;
    } catch (ex) {
      logger.e(ex);
      if (_isDisposed) return;
      updateStatus = StockUpdateStatus.failed;
      _notifyListenersIfActive();
      return;
    }
    // 3️⃣ 更新完成後，再抓一次（刷新畫面🔥）
    updateStatus = StockUpdateStatus.succeeded;
    _notifyListenersIfActive();
  }

  Future<void> _useStocksIfAvailable(List<ModelStock> availableStocks) async {
    if (_isDisposed || availableStocks.isEmpty) return;

    stocks = availableStocks;
    await buildDashboard(stocks.first.date);
  }

  Future<void> buildDashboard(DateTime? date) async {
    if (_isDisposed) return;
    date = date ?? await service.getLatestDate();
    if (_isDisposed || date == null) {
      return;
    }
    // ==========
    // 外資買超 Top30
    // ==========
    institutionals = await service.selectStockInstitutional(date);
    if (_isDisposed) return;
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

  void _notifyListenersIfActive() {
    if (!_isDisposed) notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }
}
