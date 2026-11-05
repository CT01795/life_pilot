import 'package:life_pilot/auth/controller_auth.dart';
import 'package:life_pilot/subscription/model_admin_subscription_page.dart';
import 'package:life_pilot/utils/safe_change_notifier.dart';

class ControllerAdminSubscriptionPage extends SafeChangeNotifier {
  ControllerAdminSubscriptionPage({
    required this.auth,
    required AdminSubscriptionPageLoader load,
  }) : _load = load {
    _owner = auth.currentAccount;
    auth.addListener(_accountChanged);
  }
  final ControllerAuth auth;
  final AdminSubscriptionPageLoader _load;
  String? _owner;
  int _revision = 0;
  List<AdminSubscriptionSummary> rows = const [];
  bool loading = false, hasMore = false;
  Object? error;
  bool retryMore = false;
  AdminSubscriptionCursor? _cursor;
  bool _current(int revision) =>
      !notifierDisposed &&
      revision == _revision &&
      auth.currentAccount == _owner;
  void _accountChanged() {
    if (_owner == auth.currentAccount) return;
    _owner = auth.currentAccount;
    _revision++;
    rows = const [];
    loading = false;
    hasMore = false;
    error = null;
    retryMore = false;
    _cursor = null;
    notifyListeners();
  }

  Future<void> load({bool more = false}) async {
    if (notifierDisposed || loading || (more && !hasMore)) return;
    final revision = more ? _revision : ++_revision;
    loading = true;
    error = null;
    retryMore = more;
    notifyListeners();
    try {
      final page = await _load(after: more ? _cursor : null);
      if (!_current(revision)) return;
      if (page.hasMore && page.cursor == null) {
        throw const FormatException('Missing subscription cursor');
      }
      rows = List.unmodifiable(more ? [...rows, ...page.rows] : page.rows);
      _cursor = page.cursor;
      hasMore = page.hasMore;
    } catch (failure) {
      if (_current(revision)) error = failure;
    } finally {
      if (_current(revision)) {
        loading = false;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    auth.removeListener(_accountChanged);
    super.dispose();
  }
}
