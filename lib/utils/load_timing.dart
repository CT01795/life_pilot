import 'package:flutter/foundation.dart';

/// Local-only diagnostics. Callers pass fixed stage labels and counts, never
/// account names, record contents or URLs. Disabled in release builds.
class LoadTiming {
  LoadTiming(
    this.label, {
    this.enabled = !kReleaseMode,
    this.group = 'MemoryLoad',
    void Function(String)? log,
  }) : _log = log ?? debugPrint,
       _id = ++_nextId {
    if (enabled) _watch.start();
  }

  static int _nextId = 0;
  final String label;
  final String group;
  final bool enabled;
  final void Function(String) _log;
  final int _id;
  final Stopwatch _watch = Stopwatch();
  final Set<String> _reported = {};
  int _previousMicros = 0;

  void mark(String stage, {int? rows, bool once = false}) {
    if (!enabled || (once && _reported.contains(stage))) return;
    _reported.add(stage);
    final elapsed = _watch.elapsedMicroseconds;
    final delta = elapsed - _previousMicros;
    _previousMicros = elapsed;
    _log(
      '[$group $label#$_id] $stage '
      'elapsed=${(elapsed / 1000).toStringAsFixed(1)}ms '
      'step=${(delta / 1000).toStringAsFixed(1)}ms'
      '${rows == null ? '' : ' rows=$rows'}',
    );
  }

  /// Observes an existing operation without retries, extra requests or changing
  /// its result/error. Labels must be fixed strings, never user data.
  Future<T> measure<T>(String stage, Future<T> Function() operation) async {
    mark('${stage}_start');
    try {
      final result = await operation();
      mark('${stage}_complete');
      return result;
    } catch (_) {
      mark('${stage}_failed');
      rethrow;
    }
  }
}
