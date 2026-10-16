@TestOn('browser')
library;

// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter
import 'dart:html' as html;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/game/model_blockly_message_queue.dart';
import 'package:life_pilot/game/widgets_blockly_web_editor.dart';
import 'package:life_pilot/game/steam_scratch/page_game_steam_scratch_blockly_editor_web.dart';
import 'package:life_pilot/game/steam_scratch_maze/page_game_steam_scratch_maze_blockly_editor_web.dart';

Future<void> _waitFor(WidgetTester tester, bool Function() condition) async {
  for (var i = 0; i < 60; i++) {
    await tester.pump();
    if (condition()) return;
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
  }
  expect(
    condition(),
    true,
    reason: 'Browser iframe lifecycle did not complete',
  );
}

Future<html.IFrameElement> _prepareFrame(WidgetTester tester) async {
  WidgetsBlocklyWebEditorState state() =>
      tester.state<WidgetsBlocklyWebEditorState>(
        find.byType(WidgetsBlocklyWebEditor),
      );
  await _waitFor(tester, () => state().frame != null);
  final frame = state().frame!;
  // A deterministic stand-in avoids external Blockly/CDN requests.
  await tester.runAsync(() async {
    final loaded = frame.onLoad.first;
    frame.srcdoc = '''<html><body><script>
      window.addEventListener('message', (event) => {
        if (event.data.type === 'request_commands') {
          parent.postMessage(JSON.stringify({type:'commands_ready', bridgeId:event.data.bridgeId,
            json:JSON.stringify({xml:'<xml><block type="forward"></block></xml>'})}), '*');
        }
      });
    </script></body></html>''';
    await loaded.timeout(const Duration(seconds: 5));
  });
  return frame;
}

Widget _host(Widget child) => Directionality(
  textDirection: TextDirection.ltr,
  child: SizedBox(width: 500, height: 400, child: child),
);

void main() {
  testWidgets('maze editor starts after three separate visits', (tester) async {
    html.IFrameElement? previous;
    for (var visit = 0; visit < 3; visit++) {
      final key = GlobalKey<PageGameSteamScratchMazeBlocklyEditorState>();
      var calls = 0;
      await tester.pumpWidget(
        _host(
          PageGameSteamScratchMazeBlocklyEditor(
            key: key,
            onCommandsReady: (commands) {
              expect(commands.length, 1);
              calls++;
            },
          ),
        ),
      );
      final frame = await _prepareFrame(tester);
      expect(identical(frame, previous), false);
      previous = frame;
      key.currentState!.setMaxBlocks(10);
      await key.currentState!.requestBlocklyJson();
      await _waitFor(tester, () => calls == 1);
      expect(tester.takeException(), null);
      await tester.pumpWidget(const SizedBox());
    }
  });
  testWidgets('normal editor starts after three separate visits', (
    tester,
  ) async {
    for (var visit = 0; visit < 3; visit++) {
      final key = GlobalKey<PageGameSteamScratchBlocklyEditorState>();
      var calls = 0;
      await tester.pumpWidget(
        _host(
          PageGameSteamScratchBlocklyEditor(
            key: key,
            onCommandsReady: (commands) {
              expect(commands.length, 1);
              calls++;
            },
          ),
        ),
      );
      await _prepareFrame(tester);
      await key.currentState!.requestBlocklyJson();
      await _waitFor(tester, () => calls == 1);
      await tester.pumpWidget(const SizedBox());
    }
  });
  testWidgets('unrelated window messages cannot execute commands', (
    tester,
  ) async {
    final queue = ModelBlocklyMessageQueue();
    var calls = 0;
    await tester.pumpWidget(
      _host(
        WidgetsBlocklyWebEditor(
          messages: queue,
          onCommandsJson: (json) {
            expect(json['xml'], isNotNull);
            calls++;
          },
        ),
      ),
    );
    await _prepareFrame(tester);
    queue.requestCommands();
    html.window.postMessage(
      '{"type":"commands_ready","json":"{}"}',
      html.window.location.origin,
    );
    await _waitFor(tester, () => calls == 1);
    await tester.pump();
    expect(calls, 1);
    await tester.pumpWidget(const SizedBox());
  });
}
