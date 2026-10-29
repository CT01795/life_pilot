import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/utils/in_flight_read_pool.dart';

void main() {
  test('generic keys share a read before its fetch callback returns', () async {
    final pool = InFlightReadPool<(String, int), int>();
    final pending = Completer<int>();
    Future<int>? nested;
    var calls = 0;
    final first = pool.read(('owner', 1), () {
      calls++;
      nested = pool.read(('owner', 1), () async {
        calls++;
        return 99;
      });
      return pending.future;
    });
    expect(nested, same(first));
    expect(calls, 1);
    pending.complete(7);
    expect(await first, 7);
    expect(await nested, 7);
  });
  test(
    'different keys run independently; completed results are not cached',
    () async {
      final pool = InFlightReadPool<String, int>();
      final pending = Completer<int>();
      final a = pool.read('a', () => pending.future);
      expect(await pool.read('b', () async => 2), 2);
      pending.complete(1);
      expect(await a, 1);
      expect(await pool.read('a', () async => 3), 3);
    },
  );
  for (final fails in [false, true]) {
    test(
      'invalidated old completion preserves replacement (failure: $fails)',
      () async {
        final pool = InFlightReadPool<String, int>();
        final old = Completer<int>(), fresh = Completer<int>();
        final a = pool.read('a', () => old.future);
        final observed = fails
            ? expectLater(a, throwsStateError)
            : a.then<void>((_) {});
        pool.invalidate();
        final b = pool.read('a', () => fresh.future);
        if (fails) {
          old.completeError(StateError('old'));
        } else {
          old.complete(1);
        }
        await observed;
        expect(pool.read('a', () async => 99), same(b));
        fresh.complete(2);
        expect(await b, 2);
      },
    );
  }
  test('synchronous failure releases its slot for immediate retry', () async {
    final pool = InFlightReadPool<String, int>();
    await expectLater(
      pool.read('a', () => throw StateError('offline')),
      throwsStateError,
    );
    expect(await pool.read('a', () async => 2), 2);
  });
  testWidgets('optional timeout observes late errors and permits retry', (
    tester,
  ) async {
    final pool = InFlightReadPool<String, int>();
    final pending = Completer<int>();
    final first = pool.read(
      'a',
      () => pending.future,
      timeout: const Duration(seconds: 1),
    );
    final observed = expectLater(first, throwsA(isA<TimeoutException>()));
    await tester.pump(const Duration(seconds: 2));
    await observed;
    expect(await pool.read('a', () async => 2), 2);
    pending.completeError(StateError('late'));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
