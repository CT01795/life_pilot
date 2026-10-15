import 'package:life_pilot/stock/model_stock.dart';
import 'package:life_pilot/stock/model_stock_search_index.dart';
import 'package:life_pilot/stock/service_stock.dart';
import 'package:life_pilot/utils/logger.dart';
import 'package:life_pilot/utils/safe_change_notifier.dart';

enum StockUpdateStatus { idle, updating, succeeded, failed }

class ControllerStock extends SafeChangeNotifier {
  final ServiceStock service;

  StockSearchIndex<ModelStock> _stockSearch = StockSearchIndex(
    rows: const [],
    fields: _stockFields,
  );
  StockSearchIndex<ModelInstitutional> _buySearch = StockSearchIndex(
    rows: const [],
    fields: _institutionalFields,
  );
  StockSearchIndex<ModelInstitutional> _sellSearch = StockSearchIndex(
    rows: const [],
    fields: _institutionalFields,
  );
  static Iterable<String> _stockFields(ModelStock stock) => [
    stock.securityCode,
    stock.securityName,
  ];
  static Iterable<String> _institutionalFields(ModelInstitutional item) => [
    '${item.stockNo} ${item.stockName}',
  ];
  List<ModelStock> get stocks => _stockSearch.rows;
  set stocks(List<ModelStock> rows) =>
      _stockSearch = StockSearchIndex(rows: rows, fields: _stockFields);
  List<ModelFuture> futures = [];
  List<ModelInstitutional> institutionals = [];
  List<ModelInstitutional> get foreignBuy => _buySearch.rows;
  set foreignBuy(List<ModelInstitutional> rows) =>
      _buySearch = StockSearchIndex(rows: rows, fields: _institutionalFields);
  List<ModelInstitutional> get foreignSell => _sellSearch.rows;
  set foreignSell(List<ModelInstitutional> rows) =>
      _sellSearch = StockSearchIndex(rows: rows, fields: _institutionalFields);
  bool loading = true;
  bool loadFailed = false;
  bool dateLoading = false;
  DateTime? selectedDate;
  DateTime? latestAvailableDate;
  StockUpdateStatus updateStatus = StockUpdateStatus.idle;
  String searchQuery = '';
  bool _isDisposed = false;
  int _dataRequestId = 0;

  ControllerStock(this.service);

  List<ModelStock> get visibleStocks => _stockSearch.filter(searchQuery);
  List<ModelInstitutional> get visibleForeignBuy =>
      _buySearch.filter(searchQuery);
  List<ModelInstitutional> get visibleForeignSell =>
      _sellSearch.filter(searchQuery);

  void setSearchQuery(String value) {
    if (searchQuery == value) return;
    searchQuery = value;
    _notifyListenersIfActive();
  }

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
    List<ModelStock> availableStocks,
    int requestId,
  ) async {
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
      final loadedStocks = await service.getSimpleStrategyForDate(date);
      if (_isDisposed || requestId != _dataRequestId) return;
      stocks = loadedStocks;
      await buildDashboard(date, requestId: requestId);
      if (_isDisposed || requestId != _dataRequestId) return;
      loadFailed = stocks.isEmpty;
    } catch (error, stackTrace) {
      logger.e(
        'Load stocks by date failed',
        error: error,
        stackTrace: stackTrace,
      );
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
    final loadedInstitutionals = await service.selectStockInstitutional(date);
    if (_isDisposed || requestId != _dataRequestId) return;
    institutionals = loadedInstitutionals;
    foreignBuy =
        loadedInstitutionals.where((row) => row.foreignDiff > 0).toList()
          ..sort((a, b) => b.foreignDiff.compareTo(a.foreignDiff));
    foreignSell =
        loadedInstitutionals.where((row) => row.foreignDiff < 0).toList()
          ..sort((a, b) => a.foreignDiff.compareTo(b.foreignDiff));

    // ==========
    // 期貨未平倉
    // ==========

    try {
      final loadedFutures = await service.selectFutures(date);
      if (_isDisposed || requestId != _dataRequestId) return;
      futures = loadedFutures;
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
