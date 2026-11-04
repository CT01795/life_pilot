/// Coalesces account refreshes for one visit to the proposal review page.
class ControllerLedgerReviewRefresh {
  ControllerLedgerReviewRefresh(this._refresh);

  final void Function() _refresh;
  bool _closed = false;
  bool _changed = false;

  void approved() {
    if (_closed) {
      // A write can finish after navigation has already returned.
      _refresh();
    } else {
      _changed = true;
    }
  }

  void close() {
    if (_closed) return;
    _closed = true;
    if (_changed) _refresh();
  }
}
