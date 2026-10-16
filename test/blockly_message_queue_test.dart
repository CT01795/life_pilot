import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/game/model_blockly_message_queue.dart';

void main() {
  late ModelBlocklyMessageQueue queue;
  late List<Map<String, dynamic>> sent;
  setUp(() {
    queue = ModelBlocklyMessageQueue();
    sent = [];
  });
  tearDown(() => queue.dispose());
  test('early max blocks and start flush in correct order after load', () {
    queue.setMaxBlocks(10);
    queue.requestCommands();
    queue.attach(sent.add);
    expect(sent, isEmpty);
    queue.markReady();
    expect(sent, [
      {'type': 'set_max_blocks', 'maxBlocks': 10},
      {'type': 'request_commands'},
    ]);
  });
  test('ready cannot be set before a frame has attached', () {
    queue.markReady();
    queue.requestCommands();
    queue.attach(sent.add);
    expect(sent, isEmpty);
    queue.markReady();
    expect(sent, [
      {'type': 'request_commands'},
    ]);
  });
  test('repeated early starts are coalesced into one request', () {
    for (var i = 0; i < 20; i++) {
      queue.requestCommands();
    }
    queue.attach(sent.add);
    queue.markReady();
    expect(sent.length, 1);
  });
  test(
    'attached but still loading retains requests and latest block limit',
    () {
      queue.attach(sent.add);
      queue.setMaxBlocks(2);
      queue.setMaxBlocks(8);
      queue.requestCommands();
      expect(sent, isEmpty);
      queue.markReady();
      expect(sent.first['maxBlocks'], 8);
      expect(sent.last['type'], 'request_commands');
    },
  );
  test('starts while response is pending do not duplicate a run', () {
    queue.attach(sent.add);
    queue.markReady();
    queue.requestCommands();
    queue.requestCommands();
    expect(sent.length, 1);
    expect(queue.completeRequest(), true);
    expect(queue.completeRequest(), false);
  });
  test('unsolicited completion is ignored', () {
    expect(queue.completeRequest(), false);
    queue.attach(sent.add);
    queue.markReady();
    expect(queue.completeRequest(), false);
  });
  test('completed request allows the next start', () {
    queue.attach(sent.add);
    queue.markReady();
    queue.requestCommands();
    queue.completeRequest();
    queue.requestCommands();
    expect(sent.length, 2);
  });
  test(
    'replacement frame retains in-flight start without sending to old frame',
    () {
      final replacement = <Map<String, dynamic>>[];
      queue.attach(sent.add);
      queue.markReady();
      queue.requestCommands();
      queue.attach(replacement.add);
      expect(replacement, isEmpty);
      queue.markReady();
      expect(sent.length, 1);
      expect(replacement, [
        {'type': 'request_commands'},
      ]);
    },
  );
  test('replacement frame receives block limit again', () {
    final replacement = <Map<String, dynamic>>[];
    queue.attach(sent.add);
    queue.setMaxBlocks(6);
    queue.markReady();
    queue.attach(replacement.add);
    queue.markReady();
    expect(replacement, [
      {'type': 'set_max_blocks', 'maxBlocks': 6},
    ]);
  });
  test('dispose prevents later load and start actions', () {
    queue.attach(sent.add);
    queue.requestCommands();
    queue.dispose();
    queue.markReady();
    queue.setMaxBlocks(4);
    queue.requestCommands();
    queue.attach(sent.add);
    expect(sent, isEmpty);
    expect(queue.completeRequest(), false);
  });
  test('block limit can change after load including zero', () {
    queue.attach(sent.add);
    queue.markReady();
    queue.setMaxBlocks(0);
    queue.setMaxBlocks(3);
    expect(sent, [
      {'type': 'set_max_blocks', 'maxBlocks': 0},
      {'type': 'set_max_blocks', 'maxBlocks': 3},
    ]);
  });
  test('duplicate load notification does not resend start', () {
    queue.attach(sent.add);
    queue.requestCommands();
    queue.markReady();
    queue.markReady();
    expect(sent.length, 1);
  });
  test('new editor state is independent of disposed old state', () {
    queue.attach(sent.add);
    queue.markReady();
    queue.dispose();
    final fresh = ModelBlocklyMessageQueue();
    final freshSent = <Map<String, dynamic>>[];
    fresh.requestCommands();
    fresh.attach(freshSent.add);
    fresh.markReady();
    expect(freshSent, [
      {'type': 'request_commands'},
    ]);
    expect(sent, isEmpty);
    fresh.dispose();
  });
}
