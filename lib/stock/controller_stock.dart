import 'dart:async';

import 'package:life_pilot/stock/model_stock.dart';
import 'package:life_pilot/stock/model_stock_institutional_rankings.dart';
import 'package:life_pilot/stock/stock_request_pool.dart';
import 'package:life_pilot/stock/model_stock_search_index.dart';
import 'package:life_pilot/stock/service_stock.dart';
import 'package:life_pilot/utils/logger.dart';
import 'package:life_pilot/utils/date_time.dart';
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
  StockSearchIndex<ModelFuture> _futuresSearch = StockSearchIndex(
    rows: const [],
    fields: _futuresFields,
  );
  static Iterable<String> _futuresFields(ModelFuture item) => [
    item.productName ?? '',
    item.identityType ?? '',
  ];
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
  List<ModelFuture> get futures => _futuresSearch.rows;
  set futures(List<ModelFuture> rows) =>
      _futuresSearch = StockSearchIndex(rows: rows, fields: _futuresFields);
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
  bool institutionalsLoading = false;
  bool futuresLoading = false;
  Object? institutionalsError;
  Object? futuresError;
  final Duration requestTimeout;
  final _institutionalReads = StockRequestPool<List<ModelInstitutional>>();
  final _futuresReads = StockRequestPool<List<ModelFuture>>();
  int _institutionalAttempt = 0, _futuresAttempt = 0;
  DateTime? selectedDate;
  DateTime? latestAvailableDate;
  StockUpdateStatus updateStatus = StockUpdateStatus.idle;
  String searchQuery = '';
  bool _isDisposed = false;
  int _dataRequestId = 0;
  int _dashboardRequestId = 0;
  Future<void>? _dashboardLoad;
  Future<void>? _activeLoad;

  ControllerStock(
    this.service, {
    this.requestTimeout = const Duration(seconds: 30),
  });

  void _invalidateDashboardReads() {
    _institutionalReads.invalidate();
    _futuresReads.invalidate();
  }

  void _clearDashboardRows() {
    institutionals = [];
    foreignBuy = [];
    foreignSell = [];
    futures = [];
  }

  List<ModelStock> get visibleStocks => _stockSearch.filter(searchQuery);
  List<ModelFuture> get visibleFutures => _futuresSearch.filter(searchQuery);
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
      !institutionalsLoading &&
      !futuresLoading &&
      latestAvailableDate != null &&
      (updateStatus == StockUpdateStatus.succeeded ||
          updateStatus == StockUpdateStatus.failed);

  /// Reuse only the current page load, including its backend update. Completed
  /// results are not cached, and repeated calls never queue another update.
  Future<void> load() {
    if (_isDisposed) return Future<void>.value();
    final active = _activeLoad;
    if (active != null) return active;

    // Publish before _load notifies listeners: a listener may call load again.
    final completion = Completer<void>();
    final request = completion.future;
    _activeLoad = request;
    void release() {
      if (identical(_activeLoad, request)) _activeLoad = null;
    }

    unawaited(
      Future<void>.sync(_load).then<void>(
        (_) {
          release();
          completion.complete();
        },
        onError: (Object error, StackTrace stack) {
          release();
          completion.completeError(error, stack);
        },
      ),
    );
    return request;
  }

  Future<void> _load() async {
    if (_isDisposed) return;
    final requestId = ++_dataRequestId;
    _dashboardLoad = null;
    _invalidateDashboardReads();
    institutionalsError = null;
    futuresError = null;
    institutionalsLoading = false;
    futuresLoading = false;
    loading = true;
    loadFailed = false;
    updateStatus = StockUpdateStatus.idle;
    _notifyListenersIfActive();

    var initialSourceLoaded = false;

    // 1️⃣ 先顯示現有資料（快速）
    try {
      _useStocksIfAvailable(
        await service
            .getSimpleStrategySupabase("From Supabase 1")
            .timeout(requestTimeout),
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
      _useStocksIfAvailable(
        await service.getSimpleStrategy("Updating 2").timeout(requestTimeout),
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
      _invalidateDashboardReads();
      final updated = await service
          .getSimpleStrategy("Updated 3")
          .timeout(requestTimeout);
      if (_isDisposed || requestId != _dataRequestId) return;
      _useStocksIfAvailable(updated, requestId);
      if (updated.isEmpty && stocks.isNotEmpty) {
        _dashboardLoad = buildDashboard(selectedDate, requestId: requestId);
      }
      if (_isDisposed || requestId != _dataRequestId) return;
      await _dashboardLoad;
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

  void _useStocksIfAvailable(List<ModelStock> availableStocks, int requestId) {
    if (_isDisposed || requestId != _dataRequestId || availableStocks.isEmpty) {
      return;
    }

    final changedDate = selectedDate != availableStocks.first.date;
    stocks = availableStocks;
    selectedDate = stocks.first.date;
    final availableDate = stocks.first.date;
    if (latestAvailableDate == null ||
        availableDate.isAfter(latestAvailableDate!)) {
      latestAvailableDate = availableDate;
    }
    if (changedDate) {
      _clearDashboardRows();
    }
    loading = false;
    loadFailed = false;
    _dashboardLoad = buildDashboard(stocks.first.date, requestId: requestId);
    _notifyListenersIfActive();
  }

  bool _canReuseSelectedDate(DateTime date) =>
      selectedDate != null &&
      !loading &&
      !loadFailed &&
      !institutionalsLoading &&
      !futuresLoading &&
      institutionalsError == null &&
      futuresError == null &&
      stocks.isNotEmpty &&
      DateTimeCompare.isSameDay(selectedDate, date) &&
      DateTimeCompare.isSameDay(stocks.first.date, date);

  /// Reuse only the fully loaded date currently on screen, never a historical
  /// cache. Explicit refreshes and incomplete/failed data still query afresh.
  Future<void> loadDate(DateTime date, {bool force = false}) async {
    if (_isDisposed || dateLoading) return;
    if (!force && _canReuseSelectedDate(date)) return;
    final requestId = ++_dataRequestId;
    institutionalsLoading = false;
    futuresLoading = false;
    dateLoading = true;
    institutionalsError = null;
    futuresError = null;
    loadFailed = false;
    selectedDate = date;
    _notifyListenersIfActive();
    try {
      final loadedStocks = await service
          .getSimpleStrategyForDate(date)
          .timeout(requestTimeout);
      if (_isDisposed || requestId != _dataRequestId) return;
      stocks = loadedStocks;
      _clearDashboardRows();
      // Historical stock rows are ready; other sections finish independently.
      dateLoading = false;
      _dashboardLoad = buildDashboard(date, requestId: requestId);
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
      _clearDashboardRows();
      loadFailed = true;
    } finally {
      if (!_isDisposed && requestId == _dataRequestId) {
        dateLoading = false;
        _notifyListenersIfActive();
      }
    }
  }

  Future<void> buildDashboard(DateTime? date, {int? requestId}) async {
    if (_isDisposed) return;
    requestId ??= _dataRequestId;
    final dashboardRequest = ++_dashboardRequestId;
    date = date ?? await service.getLatestDate().timeout(requestTimeout);
    bool isCurrent() =>
        !_isDisposed &&
        requestId == _dataRequestId &&
        dashboardRequest == _dashboardRequestId;
    if (!isCurrent() || date == null) {
      return;
    }
    // Publish a coherent loading snapshot once, before starting either read.
    institutionalsLoading = true;
    futuresLoading = true;
    institutionalsError = null;
    futuresError = null;
    _notifyListenersIfActive();
    if (!isCurrent()) return;
    final targetDate = date;
    await Future.wait([
      _readInstitutionals(
        targetDate,
        requestId,
        dashboardRequest,
        announceStart: false,
      ),
      _readFutures(
        targetDate,
        requestId,
        dashboardRequest,
        announceStart: false,
      ),
    ]);
  }

  bool _isDashboardCurrent(int request, int dashboard) =>
      !_isDisposed &&
      request == _dataRequestId &&
      dashboard == _dashboardRequestId;

  Future<void> retryInstitutionals() async {
    final date = selectedDate;
    if (_isDisposed || date == null || institutionalsLoading) return;
    _institutionalReads.invalidate();
    await _readInstitutionals(date, _dataRequestId, _dashboardRequestId);
  }

  Future<void> retryFutures() async {
    final date = selectedDate;
    if (_isDisposed || date == null || futuresLoading) return;
    _futuresReads.invalidate();
    await _readFutures(date, _dataRequestId, _dashboardRequestId);
  }

  Future<void> _readInstitutionals(
    DateTime targetDate,
    int request,
    int dashboard, {
    bool announceStart = true,
  }) async {
    if (!_isDashboardCurrent(request, dashboard)) return;
    final attempt = ++_institutionalAttempt;
    bool isCurrent() =>
        _isDashboardCurrent(request, dashboard) &&
        attempt == _institutionalAttempt;
    if (announceStart) {
      institutionalsLoading = true;
      institutionalsError = null;
      _notifyListenersIfActive();
    }
    try {
      // A synchronous listener can change the date or dispose this page.
      if (!isCurrent()) return;
      final rows = await _institutionalReads.read(
        targetDate,
        () => service.selectStockInstitutional(targetDate),
        requestTimeout,
      );
      if (!isCurrent()) return;
      final rankings = ModelStockInstitutionalRankings(rows);
      institutionals = rows;
      foreignBuy = rankings.buy;
      foreignSell = rankings.sell;
    } catch (error, stackTrace) {
      if (isCurrent()) {
        institutionalsError = error;
        logger.e(
          'Stock institutional load failed',
          error: error,
          stackTrace: stackTrace,
        );
      }
    } finally {
      if (isCurrent()) {
        institutionalsLoading = false;
        _notifyListenersIfActive();
      }
    }
  }

  Future<void> _readFutures(
    DateTime targetDate,
    int request,
    int dashboard, {
    bool announceStart = true,
  }) async {
    if (!_isDashboardCurrent(request, dashboard)) return;
    final attempt = ++_futuresAttempt;
    bool isCurrent() =>
        _isDashboardCurrent(request, dashboard) && attempt == _futuresAttempt;
    if (announceStart) {
      futuresLoading = true;
      futuresError = null;
      _notifyListenersIfActive();
    }
    try {
      if (!isCurrent()) return;
      final rows = await _futuresReads.read(
        targetDate,
        () => service.selectFutures(targetDate),
        requestTimeout,
      );
      if (isCurrent()) futures = rows;
    } catch (error, stackTrace) {
      if (isCurrent()) {
        futuresError = error;
        logger.e(
          'Stock futures load failed',
          error: error,
          stackTrace: stackTrace,
        );
      }
    } finally {
      if (isCurrent()) {
        futuresLoading = false;
        _notifyListenersIfActive();
      }
    }
  }

  void _notifyListenersIfActive() {
    if (!_isDisposed) notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _invalidateDashboardReads();
    super.dispose();
  }
}
