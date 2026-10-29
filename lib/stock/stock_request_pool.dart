import 'package:life_pilot/utils/in_flight_read_pool.dart';

/// Controller-owned in-flight reads only: completed results are never cached.
/// Invalidating after writes prevents joining a pre-update request.
class StockRequestPool<T> {
  final _reads = InFlightReadPool<DateTime, T>();

  Future<T> read(DateTime date, Future<T> Function() fetch, Duration timeout) {
    final day = DateTime(date.year, date.month, date.day);
    return _reads.read(day, fetch, timeout: timeout);
  }

  void invalidate() => _reads.invalidate();
}
