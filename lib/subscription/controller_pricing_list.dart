import 'package:life_pilot/utils/safe_change_notifier.dart';
import 'package:life_pilot/utils/refresh_request_coordinator.dart';

/// Lazy view data only. Never use the displayed list as a write authorization.
class ControllerPricingList<T> extends SafeChangeNotifier {
  ControllerPricingList({
    required Future<List<T>> Function({bool force}) load,
    this.timeout = const Duration(seconds: 30),
  }) : _load = load;
  final Future<List<T>> Function({bool force}) _load;
  final Duration timeout;
  List<T> rows = const [];
  bool loading = false, loaded = false;
  Object? error;
  int _revision = 0;
  final RefreshRequestCoordinator _loads = RefreshRequestCoordinator();
  bool get ready => loaded && !loading && error == null;

  Future<void> load({bool force = false}) {
    if (notifierDisposed || (!force && loaded && !_loads.isRunning)) {
      return Future<void>.value();
    }
    if (force && _loads.isRunning) _revision++;
    return _loads.run(() => _loadOnce(force: force), force: force);
  }

  Future<void> _loadOnce({required bool force}) async {
    if (notifierDisposed) return;
    final revision = ++_revision;
    loading = true;
    error = null;
    notifyListeners();
    try {
      final result = await _load(force: force).timeout(timeout);
      if (notifierDisposed || revision != _revision) return;
      rows = List.unmodifiable(result);
      loaded = true;
    } catch (failure) {
      if (!notifierDisposed && revision == _revision) error = failure;
    } finally {
      if (!notifierDisposed && revision == _revision) {
        loading = false;
        notifyListeners();
      }
    }
  }
}
