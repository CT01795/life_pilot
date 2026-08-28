import 'package:flutter/foundation.dart';

/// A [ChangeNotifier] that silently ignores notifications after disposal.
///
/// Async work cannot always be cancelled (for example, an HTTP request already
/// in flight). This base class prevents a late completion from notifying a
/// controller whose page has already been removed.
abstract class SafeChangeNotifier extends ChangeNotifier {
  bool _notifierDisposed = false;

  bool get notifierDisposed => _notifierDisposed;

  @override
  void notifyListeners() {
    if (_notifierDisposed) return;
    super.notifyListeners();
  }

  @mustCallSuper
  @override
  void dispose() {
    _notifierDisposed = true;
    super.dispose();
  }
}
