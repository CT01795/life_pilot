import 'dart:async';
import 'package:life_pilot/auth/controller_auth.dart';
import 'package:life_pilot/event/model_content_performance.dart';
import 'package:life_pilot/event/model_content_performance_period.dart';
import 'package:life_pilot/event/service_content_performance.dart';
import 'package:life_pilot/utils/safe_change_notifier.dart';
import 'package:life_pilot/utils/refresh_request_coordinator.dart';
import 'package:life_pilot/utils/logger.dart';

class ControllerContentPerformance extends SafeChangeNotifier {
  final ControllerAuth auth;
  final bool attractions;
  final ServiceContentPerformance service;
  final String? _owner;
  String? _observedAccount;
  final Duration requestTimeout;
  int _personalDataRevision;
  int _request = 0;
  bool loading = false;
  Object? error;
  ModelContentPerformance? data;
  bool loadingMore = false;
  Object? moreError;
  ContentPerformancePeriod? _loadedPeriod;
  String _loadedKeyword = '';
  DateTime? selectedMonth;
  String keyword = '';
  RefreshRequestCoordinator _loads = RefreshRequestCoordinator();
  Object? _loadKey;
  ControllerContentPerformance({
    required this.auth,
    required this.attractions,
    ServiceContentPerformance? service,
    this.requestTimeout = const Duration(seconds: 30),
  }) : service = service ?? ServiceContentPerformance(),
       _owner = auth.currentAccount,
       _observedAccount = auth.currentAccount,
       _personalDataRevision = auth.personalDataRevision {
    auth.addListener(_authChanged);
  }
  void _authChanged() {
    if (notifierDisposed) return;
    final account = auth.currentAccount;
    if (_observedAccount != account ||
        _personalDataRevision != auth.personalDataRevision) {
      _request++;
      _observedAccount = account;
      _loads = RefreshRequestCoordinator();
      _loadKey = null;
      data = null;
      loadingMore = false;
      moreError = null;
      _loadedPeriod = null;
      error = null;
      loading = false;
      _personalDataRevision = auth.personalDataRevision;
      notifyListeners();
      if (_owner == auth.currentAccount) unawaited(load());
    }
  }

  Future<void> load({bool force = false}) {
    if (notifierDisposed ||
        _owner == null ||
        _owner.isEmpty ||
        _owner != auth.currentAccount) {
      return Future<void>.value();
    }
    final period = ContentPerformancePeriod(
      month: selectedMonth,
      now: DateTime.now(),
    );
    final search = keyword.trim();
    final key = (period.month, period.today, search, auth.personalDataRevision);
    if (_loadKey != key) {
      _request++;
      _loads = RefreshRequestCoordinator();
      _loadKey = key;
    }
    final loads = _loads;
    if (force && loads.isRunning) _request++;
    return loads.run(() {
      if (notifierDisposed || !identical(loads, _loads)) {
        return Future<void>.value();
      }
      return _load(period, search);
    }, force: force);
  }

  Future<void> _load(ContentPerformancePeriod period, String search) async {
    if (notifierDisposed ||
        _owner == null ||
        _owner.isEmpty ||
        _owner != auth.currentAccount) {
      return;
    }
    final request = ++_request;
    loadingMore = false;
    moreError = null;
    _loadedPeriod = null;
    loading = true;
    data = null;
    error = null;
    notifyListeners();
    if (!_isCurrentRequest(request)) {
      return;
    }
    var reading = true;
    try {
      final result = await service
          .read(
            owner: _owner,
            attractions: attractions,
            period: period,
            keyword: search,
            statisticsOnly: true,
            shouldContinue: () => reading && _isCurrentRequest(request),
          )
          .timeout(requestTimeout);
      if (_isCurrentRequest(request)) {
        data = result;
        _loadedPeriod = period;
        _loadedKeyword = search;
      }
    } catch (failure, stack) {
      if (_isCurrentRequest(request)) {
        error = failure;
        logger.w(
          'Content performance query failed (${attractions ? 'attractions' : 'events'})',
          error: failure,
          stackTrace: stack,
        );
      }
    } finally {
      // Future.timeout does not abort the underlying HTTP request. Stop its
      // pagination when it eventually returns, including after a timeout.
      reading = false;
      if (_isCurrentRequest(request)) {
        loading = false;
        notifyListeners();
      }
    }
  }

  bool _isCurrentRequest(int request) =>
      !notifierDisposed &&
      request == _request &&
      _owner == auth.currentAccount &&
      _personalDataRevision == auth.personalDataRevision;

  Future<void> loadMore() async {
    final current = data;
    final offset = current?.nextOffset;
    final period = _loadedPeriod;
    final request = _request;
    if (loading ||
        loadingMore ||
        offset == null ||
        period == null ||
        !_isCurrentRequest(request)) {
      return;
    }
    loadingMore = true;
    moreError = null;
    notifyListeners();
    try {
      if (!_isCurrentRequest(request)) return;
      final page = await service
          .readNextPage(
            owner: _owner!,
            attractions: attractions,
            period: period,
            keyword: _loadedKeyword,
            offset: offset,
            shouldContinue: () => _isCurrentRequest(request),
          )
          .timeout(requestTimeout);
      if (!_isCurrentRequest(request)) return;
      if (page == null ||
          (page.nextOffset != null && page.nextOffset! <= offset)) {
        throw StateError('Invalid performance continuation');
      }
      data = current!.appendPage(page);
    } catch (failure) {
      if (_isCurrentRequest(request)) moreError = failure;
    } finally {
      if (_isCurrentRequest(request)) {
        loadingMore = false;
        notifyListeners();
      }
    }
  }

  Future<void> selectMonth(DateTime? month, {String? keyword}) async {
    if (notifierDisposed) return;
    selectedMonth = month == null ? null : DateTime(month.year, month.month);
    if (keyword != null) this.keyword = keyword.trim();
    await load();
  }

  Future<void> search(String value) async {
    if (notifierDisposed) return;
    keyword = value.trim();
    await load();
  }

  @override
  void dispose() {
    _request++;
    auth.removeListener(_authChanged);
    super.dispose();
  }
}
