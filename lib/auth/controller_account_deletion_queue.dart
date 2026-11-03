import 'package:life_pilot/auth/controller_auth.dart';
import 'package:life_pilot/auth/model_account_deletion_page.dart';
import 'package:life_pilot/utils/safe_change_notifier.dart';

class ControllerAccountDeletionQueue extends SafeChangeNotifier {
  ControllerAccountDeletionQueue({
    required this.auth,
    required AccountDeletionPageLoader load,
    required Future<void> Function(String) approve,
    required Future<void> Function(String) confirmCancellation,
  }) : _load = load,
       _approve = approve,
       _confirmCancellation = confirmCancellation {
    _owner = auth.currentAccount;
    _admin = auth.isSysAdmin;
    auth.addListener(_authChanged);
  }
  final ControllerAuth auth;
  final AccountDeletionPageLoader _load;
  final Future<void> Function(String) _approve, _confirmCancellation;
  String? _owner;
  bool _admin = false;
  int _revision = 0, _offset = 0;
  bool _legacy = false;
  AccountDeletionCursor? _cursor;
  List<AccountDeletionRequest> rows = const [];
  bool loading = false, working = false, hasMore = false, retryMore = false;
  Object? loadError, actionError;
  bool _current(int revision) =>
      !notifierDisposed &&
      revision == _revision &&
      _owner == auth.currentAccount &&
      auth.isSysAdmin &&
      _admin;
  void _authChanged() {
    if (_owner == auth.currentAccount && _admin == auth.isSysAdmin) return;
    _owner = auth.currentAccount;
    _admin = auth.isSysAdmin;
    _revision++;
    rows = const [];
    _cursor = null;
    _offset = 0;
    _legacy = false;
    loading = false;
    working = false;
    hasMore = false;
    loadError = null;
    actionError = null;
    notifyListeners();
  }

  Future<void> load({bool more = false}) async {
    if (!_current(_revision) || loading || working || (more && !hasMore)) {
      return;
    }
    final revision = more ? _revision : ++_revision;
    loading = true;
    loadError = null;
    retryMore = more;
    notifyListeners();
    try {
      final page = await _load(
        after: more ? _cursor : null,
        offset: more ? _offset : 0,
        legacy: more && _legacy,
      );
      if (!_current(revision)) return;
      if (page.hasMore && page.rows.isEmpty) {
        throw const FormatException('Missing deletion cursor');
      }
      final unique = {
        if (more)
          for (final row in rows) row.id: row,
        for (final row in page.rows) row.id: row,
      };
      rows = List.unmodifiable(unique.values);
      _cursor = page.rows.isEmpty ? null : page.rows.last.cursor;
      _offset = (more ? _offset : 0) + page.rows.length;
      _legacy = page.legacy;
      hasMore = page.hasMore;
    } catch (error) {
      if (_current(revision)) loadError = error;
    } finally {
      if (_current(revision)) {
        loading = false;
        notifyListeners();
      }
    }
  }

  /// Never retry a destructive operation automatically. Null = obsolete scope.
  Future<bool?> process(
    AccountDeletionRequest request, {
    Future<void> Function(String)? insteadOfApprove,
  }) async {
    if (!_current(_revision) ||
        loading ||
        working ||
        !rows.any((row) => identical(row, request))) {
      return null;
    }
    final revision = _revision;
    working = true;
    actionError = null;
    notifyListeners();
    try {
      await (request.isCancellation
          ? _confirmCancellation
          : (insteadOfApprove ?? _approve))(request.id);
      if (!_current(revision)) return null;
      rows = List.unmodifiable(rows.where((row) => row.id != request.id));
      if (_legacy && _offset > 0) _offset--;
      return true;
    } catch (error) {
      if (!_current(revision)) return null;
      actionError = error;
      return false;
    } finally {
      if (_current(revision)) {
        working = false;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    auth.removeListener(_authChanged);
    super.dispose();
  }
}
