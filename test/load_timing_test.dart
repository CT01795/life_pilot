import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/utils/load_timing.dart';

void main() {
  test('reports a fixed stage, elapsed time and optional row count', () {
    final messages = <String>[];
    final timing = LoadTiming('query', log: messages.add);
    timing.mark('start');
    timing.mark('decoded', rows: 12);
    expect(messages.length, 2);
    expect(messages.first, contains('[MemoryLoad query#'));
    expect(messages.last, contains('decoded'));
    expect(messages.last, contains('rows=12'));
    expect(messages.first, isNot(contains('rows=')));
    for (final message in messages) {
      expect(message, matches(r'elapsed=\d+\.\dms step=\d+\.\dms'));
    }
  });

  test('first-content marker is logged at most once', () {
    final messages = <String>[];
    final timing = LoadTiming('page', log: messages.add);
    timing.mark('first_content_frame', once: true);
    timing.mark('first_content_frame', once: true);
    expect(messages.length, 1);
  });

  test('successive RPC batches remain independently measurable', () {
    final messages = <String>[];
    final timing = LoadTiming('query', log: messages.add);
    for (var index = 0; index < 3; index++) {
      timing.mark('rpc_start');
      timing.mark('rpc_returned', rows: 10);
    }
    expect(messages.length, 6);
  });

  test('disabled diagnostics emit nothing', () {
    final messages = <String>[];
    final timing = LoadTiming('query', enabled: false, log: messages.add);
    timing.mark('start');
    timing.mark('complete', rows: 100);
    expect(messages, isEmpty);
  });

  test('custom group retains stage timing without changing the default', () {
    final messages = <String>[];
    LoadTiming(
      'settings',
      group: 'DashboardLoad',
      log: messages.add,
    ).mark('read');
    expect(messages.single, contains('[DashboardLoad settings#'));
  });

  test(
    'measure preserves returned identity and invokes operation once',
    () async {
      final messages = <String>[];
      final timing = LoadTiming(
        'settings',
        group: 'DashboardLoad',
        log: messages.add,
      );
      final result = <String>[];
      var calls = 0;
      expect(
        await timing.measure('read', () async {
          calls++;
          return result;
        }),
        same(result),
      );
      expect(calls, 1);
      expect(messages.first, contains('read_start'));
      expect(messages.last, contains('read_complete'));
    },
  );

  for (final synchronous in [false, true]) {
    test('measure rethrows original error, synchronous=$synchronous', () async {
      final messages = <String>[];
      final timing = LoadTiming('settings', log: messages.add);
      final error = StateError('test failure');
      await expectLater(
        timing.measure<void>('read', () {
          if (synchronous) throw error;
          return Future.error(error);
        }),
        throwsA(same(error)),
      );
      expect(messages.last, contains('read_failed'));
      expect(messages.any((line) => line.contains('test failure')), false);
    });
  }

  test(
    'disabled measure still runs the original operation without logs',
    () async {
      final messages = <String>[];
      final timing = LoadTiming('settings', enabled: false, log: messages.add);
      expect(await timing.measure('read', () async => 42), 42);
      expect(messages, isEmpty);
    },
  );
}
