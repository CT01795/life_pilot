import 'dart:async';
import 'package:life_pilot/auth/controller_auth.dart';
import 'package:life_pilot/local_storage/local_data_store.dart';
import 'package:life_pilot/record_statistics/model_record_statistics.dart';
import 'package:life_pilot/record_statistics/service_record_statistics.dart';
import 'package:life_pilot/utils/safe_change_notifier.dart';
import 'package:life_pilot/utils/refresh_request_coordinator.dart';

class ControllerRecordStatistics extends SafeChangeNotifier {
  final ControllerAuth auth;
  final ServiceRecordStatistics service;
  final String accountId;
  final RecordStatisticsKind kind;
  final String? currency;
  final bool history;
  final Duration requestTimeout;
  final String? _owner;
  DataStorageLocation _storage;
  int _personalDataRevision;
  int _request = 0;
  ModelRecordStatistics? data;
  Object? error;
  bool loading = false;
  RefreshRequestCoordinator _loads = RefreshRequestCoordinator();
  Object? _loadKey;
  ControllerRecordStatistics({
    required this.auth,
    required this.accountId,
    required this.kind,
    this.currency,
    this.history = false,
    this.requestTimeout = const Duration(seconds: 30),
    ServiceRecordStatistics? service,
  }) : service = service ?? ServiceRecordStatistics(),
       _owner = auth.currentAccount,
       _storage = auth.preferredStorage,
       _personalDataRevision = auth.personalDataRevision {
    auth.addListener(_authChanged);
  }
  void _authChanged() {
    if (_owner != auth.currentAccount ||
        _storage != auth.preferredStorage ||
        _personalDataRevision != auth.personalDataRevision) {
      _request++;
      _loads = RefreshRequestCoordinator();
      _loadKey = null;
      data = null;
      error = null;
      loading = false;
      _storage = auth.preferredStorage;
      _personalDataRevision = auth.personalDataRevision;
      notifyListeners();
      if (_owner == auth.currentAccount) unawaited(load());
    }
  }

  Future<void> load({bool force = false, num? knownTotal}) {
    if (notifierDisposed ||
        accountId.isEmpty ||
        _owner == null ||
        _owner.isEmpty ||
        _owner != auth.currentAccount) {
      return Future<void>.value();
    }
    final now = DateTime.now();
    final key = (
      auth.preferredStorage,
      auth.personalDataRevision,
      DateTime(now.year, now.month, now.day),
    );
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
      return _load(now, knownTotal: knownTotal);
    }, force: force);
  }

  Future<void> _load(DateTime now, {num? knownTotal}) async {
    if (notifierDisposed ||
        accountId.isEmpty ||
        _owner == null ||
        _owner.isEmpty ||
        _owner != auth.currentAccount) {
      return;
    }
    final request = ++_request;
    final storage = auth.preferredStorage;
    loading = true;
    error = null;
    notifyListeners();
    if (!_isCurrentRequest(request, storage)) {
      return;
    }
    try {
      final totalFuture = history
          ? Future<num?>.value(null)
          : knownTotal != null && storage == DataStorageLocation.cloud
          ? Future<num?>.value(knownTotal)
          : service.readTotal(
              owner: _owner,
              storage: storage,
              accountId: accountId,
              kind: kind,
              currency: currency,
            );
      // Attach both listeners together so a failed total request is observed
      // even while its independent month-page request is still in flight.
      final results = await Future.wait<Object?>([
        service.read(
          owner: _owner,
          storage: storage,
          accountId: accountId,
          kind: kind,
          currency: currency,
          now: now,
          history: history,
        ),
        totalFuture,
      ]).timeout(requestTimeout);
      if (!_isCurrentRequest(request, storage)) {
        return;
      }
      data = ModelRecordStatistics.fromRows(
        results[0] as List<Map<String, dynamic>>,
        now: now,
        totalOverride: results[1] as num?,
      );
    } catch (failure) {
      if (_isCurrentRequest(request, storage)) {
        error = failure;
        data = null;
      }
    } finally {
      if (_isCurrentRequest(request, storage)) {
        loading = false;
        notifyListeners();
      }
    }
  }

  bool _isCurrentRequest(int request, DataStorageLocation storage) =>
      !notifierDisposed &&
      request == _request &&
      _owner == auth.currentAccount &&
      storage == auth.preferredStorage &&
      _personalDataRevision == auth.personalDataRevision;

  @override
  void dispose() {
    _request++;
    auth.removeListener(_authChanged);
    super.dispose();
  }
}
