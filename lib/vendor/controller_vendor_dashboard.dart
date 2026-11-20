import 'dart:async';

import 'package:life_pilot/auth/controller_auth.dart';
import 'package:life_pilot/utils/refresh_request_coordinator.dart';
import 'package:life_pilot/utils/safe_change_notifier.dart';
import 'package:life_pilot/vendor/model_vendor_dashboard.dart';
import 'package:life_pilot/vendor/service_vendor_account.dart';

/// Owns dashboard requests. The page owns navigation and localized messages.
class ControllerVendorDashboard extends SafeChangeNotifier {
  ControllerVendorDashboard({
    required this.auth,
    required this.service,
    this.requestTimeout = const Duration(seconds: 30),
  }) : _owner = auth.currentAccount,
       _observedAccount = auth.currentAccount,
       _personalDataRevision = auth.personalDataRevision {
    auth.addListener(_authChanged);
  }

  final ControllerAuth auth;
  final ServiceVendorAccount service;
  final Duration requestTimeout;
  final String? _owner;
  String? _observedAccount;
  int _personalDataRevision;
  int _revision = 0;
  RefreshRequestCoordinator _loads = RefreshRequestCoordinator();
  ModelVendorDashboard? _data;
  Object? _error;
  bool _loading = false;

  ModelVendorDashboard? get data => _data;
  Object? get error => _error;
  bool get loading => _loading;

  bool _active(int revision) =>
      !notifierDisposed &&
      revision == _revision &&
      _owner == auth.currentAccount &&
      _personalDataRevision == auth.personalDataRevision;

  void _authChanged() {
    if (notifierDisposed) return;
    final account = auth.currentAccount;
    if (_observedAccount == account &&
        _personalDataRevision == auth.personalDataRevision) {
      return;
    }
    _revision++;
    _observedAccount = account;
    _personalDataRevision = auth.personalDataRevision;
    _loads = RefreshRequestCoordinator();
    _data = null;
    _error = null;
    _loading = false;
    notifyListeners();
    if (_owner == auth.currentAccount) unawaited(load());
  }

  Future<void> load({bool force = false}) {
    if (notifierDisposed ||
        _owner == null ||
        _owner.isEmpty ||
        _owner != auth.currentAccount) {
      return Future.value();
    }
    return _loads.run(() => _load(force: force));
  }

  Future<void> _load({required bool force}) async {
    final revision = ++_revision;
    _loading = true;
    _error = null;
    notifyListeners();
    var reading = true;
    try {
      if (!_active(revision)) return;
      final result = await _readDashboard(
        () => reading && _active(revision),
        force: force,
      ).timeout(requestTimeout);
      if (!_active(revision)) return;
      if (result != null) _data = result;
    } catch (error) {
      if (_active(revision)) _error = error;
    } finally {
      // Timeout does not cancel HTTP. Close this read scope so a late setup
      // response cannot launch a new request after the UI has moved on.
      reading = false;
      if (_active(revision)) {
        _loading = false;
        notifyListeners();
      }
    }
  }

  Future<ModelVendorDashboard?> _readDashboard(
    bool Function() shouldContinue, {
    required bool force,
  }) async {
    if (!shouldContinue()) return null;
    final dashboard = await service.fetchDashboard(_owner!, force: force);
    if (!shouldContinue()) return null;
    return dashboard;
  }

  @override
  void dispose() {
    _revision++;
    auth.removeListener(_authChanged);
    super.dispose();
  }
}
