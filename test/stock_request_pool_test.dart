import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/stock/stock_request_pool.dart';

void main() {
  final day = DateTime(2026, 10, 28);
  const timeout = Duration(seconds: 30);
  test('synchronous reentry joins the slot before fetch returns', () async {
    final pool = StockRequestPool<int>();
    final pending = Completer<int>();
    Future<int>? nested;
    var reads = 0;
    final first = pool.read(day, () {
      reads++;
      nested = pool.read(day, () {
        reads++;
        return Future.value(99);
      }, timeout);
      return pending.future;
    }, timeout);
    expect(nested, same(first));
    expect(reads, 1);
    pending.complete(7);
    expect(await first, 7);
    expect(await nested, 7);
  });

  test('invalidation inside fetch preserves the replacement slot', () async {
    final pool = StockRequestPool<int>();
    final old = Completer<int>(), fresh = Completer<int>();
    Future<int>? replacement;
    final first = pool.read(day, () {
      pool.invalidate();
      replacement = pool.read(day, () => fresh.future, timeout);
      return old.future;
    }, timeout);
    expect(replacement, isNot(same(first)));
    old.complete(1);
    expect(await first, 1);
    expect(pool.read(day, () async => 99, timeout), same(replacement));
    fresh.complete(2);
    expect(await replacement, 2);
  });

  test('same day joins one request; completed data is not cached', () async {
    final pool = StockRequestPool<int>();
    final pending = Completer<int>();
    var reads = 0;
    Future<int> fetch() {
      reads++;
      return pending.future;
    }

    final first = pool.read(day, fetch, timeout);
    final second = pool.read(DateTime(2026, 10, 28, 15), fetch, timeout);
    expect(second, same(first));
    pending.complete(1);
    expect(await first, 1);
    expect(await second, 1);
    expect(
      await pool.read(day, () async {
        reads++;
        return 2;
      }, timeout),
      2,
    );
    expect(reads, 2);
  });
  test('different dates do not share a request', () async {
    final pool = StockRequestPool<int>();
    final a = Completer<int>(), b = Completer<int>();
    final first = pool.read(day, () => a.future, timeout);
    final second = pool.read(DateTime(2026, 10, 27), () => b.future, timeout);
    a.complete(1);
    b.complete(2);
    expect(await first, 1);
    expect(await second, 2);
  });
  test(
    'invalidated completion cannot remove a fresh in-flight request',
    () async {
      final pool = StockRequestPool<int>();
      final old = Completer<int>(), fresh = Completer<int>();
      final first = pool.read(day, () => old.future, timeout);
      pool.invalidate();
      final second = pool.read(day, () => fresh.future, timeout);
      old.complete(1);
      await first;
      expect(
        pool.read(
          day,
          () => throw StateError('unexpected third read'),
          timeout,
        ),
        same(second),
      );
      fresh.complete(2);
      expect(await second, 2);
    },
  );
  test('synchronous failure is observed and the next read can retry', () async {
    final pool = StockRequestPool<int>();
    await expectLater(
      pool.read(day, () => throw StateError('offline'), timeout),
      throwsStateError,
    );
    expect(await pool.read(day, () async => 2, timeout), 2);
  });
  testWidgets('timeout releases the shared slot and observes late errors', (
    tester,
  ) async {
    final pool = StockRequestPool<int>();
    final old = Completer<int>();
    final first = pool.read(day, () => old.future, const Duration(seconds: 1));
    final failed = expectLater(first, throwsA(isA<TimeoutException>()));
    await tester.pump(const Duration(seconds: 2));
    await failed;
    expect(await pool.read(day, () async => 2, timeout), 2);
    old.completeError(StateError('late'));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
