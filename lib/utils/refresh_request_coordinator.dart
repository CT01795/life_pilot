import 'dart:async';

/// Coordinates refreshes, not writes. Concurrent ordinary callers share the
/// active read; forced callers share one follow-up read after it finishes.
/// Owners must still guard their data scope before and after asynchronous work.
class RefreshRequestCoordinator {
  Future<void>? _active;
  Future<void>? _queued;

  bool get isRunning => _active != null;

  Future<void> run(Future<void> Function() refresh, {bool force = false}) {
    final active = _active;
    if (active == null) return _start(refresh);
    if (!force) return active;
    final queued = _queued;
    if (queued != null) return queued;
    final completion = Completer<void>();
    _queued = completion.future;
    unawaited(_after(active, refresh, completion));
    return completion.future;
  }

  Future<void> _start(Future<void> Function() refresh) {
    final completion = Completer<void>();
    final operation = completion.future;
    // Publish before invoking refresh, which may synchronously notify callers.
    _active = operation;
    unawaited(
      Future<void>.sync(refresh).then<void>(
        (_) {
          if (identical(_active, operation)) _active = null;
          completion.complete();
        },
        onError: (Object error, StackTrace stack) {
          if (identical(_active, operation)) _active = null;
          completion.completeError(error, stack);
        },
      ),
    );
    return operation;
  }

  Future<void> _after(
    Future<void> active,
    Future<void> Function() refresh,
    Completer<void> completion,
  ) async {
    try {
      await active;
    } catch (_) {
      // The explicit queued refresh is also a retry after an unsuccessful read.
    }
    if (identical(_queued, completion.future)) _queued = null;
    try {
      await run(refresh);
      completion.complete();
    } catch (error, stack) {
      completion.completeError(error, stack);
    }
  }
}
