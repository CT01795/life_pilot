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
  List<ModelInstitutional> foreignBuy = [];
  List<ModelInstitutional> foreignSell = [];
  bool loading = true;
  bool loadFailed = false;
  bool dateLoading = false;
  DateTime? selectedDate;
  DateTime? latestAvailableDate;
  StockUpdateStatus updateStatus = StockUpdateStatus.idle;
  bool _isDisposed = false;
  int _dataRequestId = 0;

  ControllerStock(this.service);

  bool get canSelectDate =>
      !_isDisposed &&
      !loading &&
      !dateLoading &&
      latestAvailableDate != null &&
      (updateStatus == StockUpdateStatus.succeeded ||
          updateStatus == StockUpdateStatus.failed);

  Future<void> load() async {
    if (_isDisposed) return;
    final requestId = ++_dataRequestId;
    loading = true;
    loadFailed = false;
    updateStatus = StockUpdateStatus.idle;
    _notifyListenersIfActive();

    var initialSourceLoaded = false;

    // 1️⃣ 先顯示現有資料（快速）
    try {
      await _useStocksIfAvailable(
        await service.getSimpleStrategySupabase("From Supabase 1"),
        requestId,
      );
      if (_isDisposed || requestId != _dataRequestId) return;
      initialSourceLoaded = true;
      loading = false;
      _notifyListenersIfActive();
    } catch (ex) {
      logger.e(ex);
    }
    if (_isDisposed || requestId != _dataRequestId) return;

    // 1️⃣ 先顯示現有資料（快速）
    try {
      await _useStocksIfAvailable(
        await service.getSimpleStrategy("Updating 2"),
        requestId,
      );
      if (_isDisposed || requestId != _dataRequestId) return;
      initialSourceLoaded = true;
    } catch (ex) {
      logger.e(ex);
    }
    if (_isDisposed || requestId != _dataRequestId) return;

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
      if (_isDisposed || requestId != _dataRequestId) return;
      await _useStocksIfAvailable(
        await service.getSimpleStrategy("Updated 3"),
        requestId,
      );
      if (_isDisposed || requestId != _dataRequestId) return;
    } catch (ex) {
      logger.e(ex);
      if (_isDisposed || requestId != _dataRequestId) return;
      updateStatus = StockUpdateStatus.failed;
      _notifyListenersIfActive();
      return;
    }
    // 3️⃣ 更新完成後，再抓一次（刷新畫面🔥）
    if (requestId != _dataRequestId) return;
    updateStatus = StockUpdateStatus.succeeded;
    _notifyListenersIfActive();
  }

  Future<void> _useStocksIfAvailable(
      List<ModelStock> availableStocks, int requestId) async {
    if (_isDisposed || requestId != _dataRequestId || availableStocks.isEmpty) {
      return;
    }

    stocks = availableStocks;
    selectedDate = stocks.first.date;
    final availableDate = stocks.first.date;
    if (latestAvailableDate == null ||
        availableDate.isAfter(latestAvailableDate!)) {
      latestAvailableDate = availableDate;
    }
    await buildDashboard(stocks.first.date, requestId: requestId);
  }

  Future<void> loadDate(DateTime date) async {
    if (_isDisposed || dateLoading) return;
    final requestId = ++_dataRequestId;
    dateLoading = true;
    loadFailed = false;
    selectedDate = date;
    _notifyListenersIfActive();
    try {
      stocks = await service.getSimpleStrategyForDate(date);
      if (_isDisposed || requestId != _dataRequestId) return;
      await buildDashboard(date, requestId: requestId);
      if (_isDisposed || requestId != _dataRequestId) return;
      loadFailed = stocks.isEmpty;
    } catch (error, stackTrace) {
      logger.e('Load stocks by date failed',
          error: error, stackTrace: stackTrace);
      if (_isDisposed || requestId != _dataRequestId) return;
      stocks = [];
      institutionals = [];
      foreignBuy = [];
      foreignSell = [];
      futures = [];
      loadFailed = true;
    } finally {
      if (!_isDisposed) {
        dateLoading = false;
        _notifyListenersIfActive();
      }
    }
  }

  Future<void> buildDashboard(DateTime? date, {int? requestId}) async {
    if (_isDisposed) return;
    requestId ??= _dataRequestId;
    date = date ?? await service.getLatestDate();
    if (_isDisposed || requestId != _dataRequestId || date == null) {
      return;
    }
    // ==========
    // 外資買超
    // ==========
    institutionals = await service.selectStockInstitutional(date);
    if (_isDisposed || requestId != _dataRequestId) return;
    foreignBuy = [...institutionals];

    foreignBuy.sort(
      (a, b) => b.foreignDiff.compareTo(
        a.foreignDiff,
      ),
    );

    foreignBuy = foreignBuy
        .where((e) => e.foreignDiff > 0)
        .toList(); //.take(30).toList();

    // ==========
    // 外資賣超
    // ==========
    foreignSell = [...institutionals];

    foreignSell.sort(
      (a, b) => a.foreignDiff.compareTo(
        b.foreignDiff,
      ),
    );

    foreignSell = foreignSell
        .where((e) => e.foreignDiff < 0)
        .toList(); //.take(30).toList();

    // ==========
    // 期貨未平倉
    // ==========

    try {
      futures = await service.selectFutures(date);
      if (_isDisposed || requestId != _dataRequestId) return;
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
