import 'dart:async';
import 'package:life_pilot/auth/controller_auth.dart';
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
  final String? _owner;
  Object? _storage;
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
    ServiceRecordStatistics? service,
  }) : service = service ?? ServiceRecordStatistics(),
       _owner = auth.currentAccount,
       _storage = auth.preferredStorage {
    auth.addListener(_authChanged);
  }
  void _authChanged() {
    if (_owner != auth.currentAccount || _storage != auth.preferredStorage) {
      _request++;
      _loads = RefreshRequestCoordinator();
      _loadKey = null;
      data = null;
      error = null;
      loading = false;
      _storage = auth.preferredStorage;
      notifyListeners();
      if (_owner == auth.currentAccount) unawaited(load());
    }
  }

  Future<void> load({bool force = false}) {
    if (notifierDisposed ||
        accountId.isEmpty ||
        _owner == null ||
        _owner.isEmpty ||
        _owner != auth.currentAccount) {
      return Future<void>.value();
    }
    final now = DateTime.now();
    final key = (auth.preferredStorage, DateTime(now.year, now.month, now.day));
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
      return _load(now);
    }, force: force);
  }

  Future<void> _load(DateTime now) async {
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
    if (notifierDisposed ||
        request != _request ||
        _owner != auth.currentAccount ||
        storage != auth.preferredStorage) {
      return;
    }
    try {
      final totalFuture = history
          ? Future<num?>.value(null)
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
      ]);
      if (notifierDisposed ||
          request != _request ||
          _owner != auth.currentAccount ||
          storage != auth.preferredStorage) {
        return;
      }
      data = ModelRecordStatistics.fromRows(
        results[0] as List<Map<String, dynamic>>,
        now: now,
        totalOverride: results[1] as num?,
      );
    } catch (failure) {
      if (!notifierDisposed && request == _request) {
        error = failure;
        data = null;
      }
    } finally {
      if (!notifierDisposed && request == _request) {
        loading = false;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _request++;
    auth.removeListener(_authChanged);
    super.dispose();
  }
}
