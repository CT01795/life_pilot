import 'dart:async';

import 'package:life_pilot/auth/controller_auth.dart';
import 'package:life_pilot/utils/refresh_request_coordinator.dart';
import 'package:life_pilot/utils/safe_change_notifier.dart';
import 'package:life_pilot/vendor/model_vendor_account.dart';
import 'package:life_pilot/vendor/model_vendor_dashboard.dart';
import 'package:life_pilot/vendor/service_vendor_account.dart';

/// Owns dashboard requests. The page owns navigation and localized messages.
class ControllerVendorDashboard extends SafeChangeNotifier {
  ControllerVendorDashboard({required this.auth, required this.service})
    : _owner = auth.currentAccount,
      _personalDataRevision = auth.personalDataRevision {
    auth.addListener(_authChanged);
  }

  final ControllerAuth auth;
  final ServiceVendorAccount service;
  final String? _owner;
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
    if (_owner == auth.currentAccount &&
        _personalDataRevision == auth.personalDataRevision) {
      return;
    }
    _revision++;
    _personalDataRevision = auth.personalDataRevision;
    _loads = RefreshRequestCoordinator();
    _data = null;
    _error = null;
    _loading = false;
    notifyListeners();
    if (_owner == auth.currentAccount) unawaited(load());
  }

  Future<void> load() {
    if (notifierDisposed ||
        _owner == null ||
        _owner.isEmpty ||
        _owner != auth.currentAccount) {
      return Future.value();
    }
    return _loads.run(_load);
  }

  Future<void> _load() async {
    final revision = ++_revision;
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      if (!_active(revision)) return;
      await service.ensureVendorAccount();
      if (!_active(revision)) return;
      // These reads depend on account setup, not on each other's results.
      final values = await Future.wait<Object>([
        Future<VendorSubscriptionStatus>.sync(service.fetchMyStatus),
        Future<VendorContentMetrics>.sync(() => service.fetchMetrics(_owner!)),
        Future<List<VendorPricingPlan>>.sync(service.fetchPricingPlans),
      ]);
      if (!_active(revision)) return;
      _data = ModelVendorDashboard(
        status: values[0] as VendorSubscriptionStatus,
        metrics: values[1] as VendorContentMetrics,
        plans: values[2] as List<VendorPricingPlan>,
      );
    } catch (error) {
      if (_active(revision)) _error = error;
    } finally {
      if (_active(revision)) {
        _loading = false;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _revision++;
    auth.removeListener(_authChanged);
    super.dispose();
  }
}
