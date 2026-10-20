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
  final Duration requestTimeout;
  int _personalDataRevision;
  int _request = 0;
  bool loading = false;
  Object? error;
  ModelContentPerformance? data;
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
       _personalDataRevision = auth.personalDataRevision {
    auth.addListener(_authChanged);
  }
  void _authChanged() {
    if (_owner != auth.currentAccount ||
        _personalDataRevision != auth.personalDataRevision) {
      _request++;
      _loads = RefreshRequestCoordinator();
      _loadKey = null;
      data = null;
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
    loading = true;
    data = null;
    error = null;
    notifyListeners();
    if (!_isCurrentRequest(request)) {
      return;
    }
    try {
      final result = await service
          .read(
            owner: _owner,
            attractions: attractions,
            period: period,
            keyword: search,
            statisticsOnly: true,
          )
          .timeout(requestTimeout);
      if (_isCurrentRequest(request)) {
        data = result;
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
