import 'dart:async';

/// Shares active reads by key. Completed values are not cached; owners retain
/// their own account/request guards and invalidate the pool after scope changes.
class InFlightReadPool<K, T> {
  final _pending = <K, Future<T>>{};

  Future<T> read(K key, Future<T> Function() fetch, {Duration? timeout}) {
    final active = _pending[key];
    if (active != null) return active;
    final completion = Completer<T>();
    final request = completion.future;
    // Register before any callback: fetch may synchronously re-enter read.
    _pending[key] = request;
    void release() {
      if (identical(_pending[key], request)) _pending.remove(key);
    }

    var source = Future<T>.sync(fetch);
    if (timeout != null) source = source.timeout(timeout);
    unawaited(
      source.then<void>(
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

  /// Existing requests may finish, but cannot evict newer requests for the key.
  void invalidate() => _pending.clear();
}
