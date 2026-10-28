import 'dart:async';

/// Controller-owned in-flight reads only: completed results are never cached.
/// Invalidating after writes prevents joining a pre-update request.
class StockRequestPool<T> {
  final _pending = <DateTime, Future<T>>{};

  Future<T> read(DateTime date, Future<T> Function() fetch, Duration timeout) {
    final day = DateTime(date.year, date.month, date.day);
    final current = _pending[day];
    if (current != null) return current;
    // Publish before invoking fetch: synchronous callbacks may reenter read.
    final completion = Completer<T>();
    final request = completion.future;
    _pending[day] = request;
    void release() {
      if (identical(_pending[day], request)) _pending.remove(day);
    }

    // Release before completing callers, allowing an immediate retry. A late
    // invalidated read cannot evict a newer slot; timeout observes late errors.
    unawaited(
      Future<T>.sync(fetch)
          .timeout(timeout)
          .then<void>(
            (value) {
              release();
              completion.complete(value);
            },
            onError: (Object error, StackTrace stack) {
              release();
              completion.completeError(error, stack);
            },
          ),
    );
    return request;
  }

  void invalidate() => _pending.clear();
}
