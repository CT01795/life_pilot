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
}
