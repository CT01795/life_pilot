import 'package:life_pilot/utils/safe_change_notifier.dart';

/// Lazy view data only. Never use the displayed list as a write authorization.
class ControllerPricingList<T> extends SafeChangeNotifier {
  ControllerPricingList({
    required Future<List<T>> Function() load,
    this.timeout = const Duration(seconds: 30),
  }) : _load = load;
  final Future<List<T>> Function() _load;
  final Duration timeout;
  List<T> rows = const [];
  bool loading = false, loaded = false;
  Object? error;
  int _revision = 0;
  bool get ready => loaded && !loading && error == null;

  Future<void> load({bool force = false}) async {
    if (notifierDisposed || (!force && (loading || loaded))) return;
    final revision = ++_revision;
    loading = true;
    error = null;
    notifyListeners();
    try {
      final result = await _load().timeout(timeout);
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
