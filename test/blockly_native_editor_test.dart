// The fake implements the platform behind the app's existing WebView package.
// ignore_for_file: depend_on_referenced_packages
import 'dart:async';
import 'dart:convert';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/game/model_blockly_message_queue.dart';
import 'package:life_pilot/game/widgets_blockly_native_editor.dart';
import 'package:life_pilot/game/steam_scratch/page_game_steam_scratch_blockly_editor_io.dart'
    as scratch;
import 'package:life_pilot/game/steam_scratch_maze/page_game_steam_scratch_maze_blockly_editor_io.dart'
    as maze;
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart'
    as platform;

class _FakePlatform extends WebViewPlatform {
  late _FakeController controller;

  @override
  platform.PlatformWebViewController createPlatformWebViewController(
    PlatformWebViewControllerCreationParams params,
  ) => controller = _FakeController(params);

  @override
  platform.PlatformNavigationDelegate createPlatformNavigationDelegate(
    PlatformNavigationDelegateCreationParams params,
  ) => _FakeNavigation(params);

  @override
  platform.PlatformWebViewWidget createPlatformWebViewWidget(
    PlatformWebViewWidgetCreationParams params,
  ) => _FakeWidget(params);
}

class _FakeController extends platform.PlatformWebViewController {
  _FakeController(super.params) : super.implementation();
  final calls = <String>[];
  late _FakeNavigation navigation;
  late platform.JavaScriptChannelParams channel;
  Object ready = true;
  Completer<Object>? readyResult;
  bool failScript = false;
  int? currentRequestId;

  void reply(String xml, {int? requestId}) {
    channel.onMessageReceived(
      JavaScriptMessage(
        message: jsonEncode({
          'type': 'commands_ready',
          'requestId': requestId ?? currentRequestId,
          'json': jsonEncode({'xml': xml}),
        }),
      ),
    );
  }

  @override
  Future<void> setJavaScriptMode(JavaScriptMode mode) async =>
      calls.add('mode');
  @override
  Future<void> addJavaScriptChannel(
    platform.JavaScriptChannelParams params,
  ) async {
    channel = params;
    calls.add('channel');
  }

  @override
  Future<void> setPlatformNavigationDelegate(
    platform.PlatformNavigationDelegate delegate,
  ) async {
    navigation = delegate as _FakeNavigation;
    calls.add('delegate');
  }

  @override
  Future<void> loadFlutterAsset(String key) async => calls.add('asset:$key');
  @override
  Future<Object> runJavaScriptReturningResult(String script) async =>
      readyResult == null ? ready : await readyResult!.future;
  @override
  Future<void> runJavaScript(String script) async {
    if (failScript) throw StateError('test script failed');
    calls.add(script);
    final match = RegExp(
      r'^sendCommandsToFlutter\(null, null, (\d+)\)$',
    ).firstMatch(script);
    if (match != null) currentRequestId = int.parse(match.group(1)!);
  }
}

class _FakeNavigation extends platform.PlatformNavigationDelegate {
  _FakeNavigation(super.params) : super.implementation();
  late platform.PageEventCallback started;
  late platform.PageEventCallback finished;
  @override
  Future<void> setOnPageStarted(platform.PageEventCallback callback) async =>
      started = callback;
  @override
  Future<void> setOnPageFinished(platform.PageEventCallback callback) async =>
      finished = callback;
  @override
  Future<void> setOnWebResourceError(
    platform.WebResourceErrorCallback callback,
  ) async {}
}

class _FakeWidget extends platform.PlatformWebViewWidget {
  _FakeWidget(super.params) : super.implementation();
  @override
  Widget build(BuildContext context) => const SizedBox.expand();
}

Widget _host(Widget child) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: child),
);

void main() {
  late _FakePlatform fake;
  WebViewPlatform? previous;
  setUp(() {
    previous = WebViewPlatform.instance;
    WebViewPlatform.instance = fake = _FakePlatform();
  });
  tearDown(() {
    if (previous != null) WebViewPlatform.instance = previous;
  });

  Future<ModelBlocklyMessageQueue> mount(
    WidgetTester tester, {
    ValueChanged<Map<String, dynamic>>? onCommands,
  }) async {
    final queue = ModelBlocklyMessageQueue();
    await tester.pumpWidget(
      _host(
        WidgetsBlocklyNativeEditor(
          messages: queue,
          onCommandsJson: onCommands ?? (_) {},
        ),
      ),
    );
    await tester.pump();
    return queue;
  }

  testWidgets('configures bridge and delegate before loading local assets', (
    tester,
  ) async {
    await mount(tester);
    expect(fake.controller.calls, [
      'mode',
      'channel',
      'delegate',
      'asset:assets/blockly/index.html',
    ]);
    expect(fake.controller.channel.name, 'BlocklyCallback');
    final webview = tester.widget<WebViewWidget>(find.byType(WebViewWidget));
    final recognizer = webview.platform.params.gestureRecognizers.single
        .constructor();
    expect(recognizer, isA<EagerGestureRecognizer>());
    recognizer.dispose();
  });

  testWidgets('early start waits for ready and max blocks precede execution', (
    tester,
  ) async {
    final queue = await mount(tester);
    queue.setMaxBlocks(42);
    queue.requestCommands();
    fake.controller.navigation.started('asset');
    await tester.pump();
    expect(
      fake.controller.calls.where(
        (s) => s.contains('FromFlutter') || s.contains('sendCommands'),
      ),
      isEmpty,
    );
    fake.controller.navigation.finished('asset');
    await tester.pump();
    expect(fake.controller.calls.sublist(4), [
      'setMaxBlocksFromFlutter(42)',
      'sendCommandsToFlutter(null, null, 1)',
    ]);
  });

  testWidgets('late native replies cannot replace the second program', (
    tester,
  ) async {
    final received = <String>[];
    final queue = await mount(
      tester,
      onCommands: (json) => received.add(json['xml'] as String),
    );
    fake.controller.navigation.finished('asset');
    await tester.pump();
    queue.requestCommands();
    await tester.pump();
    fake.controller.reply('<xml><block type="forward"/></xml>', requestId: 1);
    queue.requestCommands();
    await tester.pump();
    fake.controller.reply('<xml><block type="forward"/></xml>', requestId: 1);
    expect(received.length, 1);
    expect(find.byIcon(Icons.refresh), findsNothing);
    fake.controller.reply('<xml><block type="jump_up"/></xml>', requestId: 2);
    fake.controller.reply('<xml><block type="jump_up"/></xml>', requestId: 2);
    expect(received, [
      '<xml><block type="forward"/></xml>',
      '<xml><block type="jump_up"/></xml>',
    ]);
  });

  testWidgets('load before max blocks does not force unwrap null', (
    tester,
  ) async {
    final queue = await mount(tester);
    fake.controller.navigation.finished('asset');
    await tester.pump();
    queue.setMaxBlocks(9);
    await tester.pump();
    expect(fake.controller.calls.last, 'setMaxBlocksFromFlutter(9)');
    expect(tester.takeException(), null);
  });

  testWidgets('only requested command replies run once', (tester) async {
    var count = 0;
    final queue = await mount(tester, onCommands: (_) => count++);
    fake.controller.navigation.finished('asset');
    await tester.pump();
    fake.controller.reply('<xml/>');
    expect(count, 0);
    queue.requestCommands();
    await tester.pump();
    fake.controller.reply('<xml/>');
    fake.controller.reply('<xml/>');
    expect(count, 1);
  });

  testWidgets(
    'failed script initialization shows retry and does not run commands',
    (tester) async {
      final queue = await mount(tester);
      fake.controller.ready = false;
      queue.requestCommands();
      fake.controller.navigation.finished('asset');
      await tester.pump();
      expect(find.byIcon(Icons.refresh), findsOneWidget);
      expect(
        fake.controller.calls.any(
          (s) => s.startsWith('sendCommandsToFlutter('),
        ),
        false,
      );
      fake.controller.ready = true;
      await tester.tap(find.byIcon(Icons.refresh));
      await tester.pump();
      fake.controller.navigation.finished('asset');
      await tester.pump();
      expect(fake.controller.calls.where((s) => s == 'channel').length, 1);
      expect(
        fake.controller.calls.last,
        'sendCommandsToFlutter(null, null, 1)',
      );
    },
  );

  testWidgets('leaving ignores delayed ready result and channel callbacks', (
    tester,
  ) async {
    var count = 0;
    final queue = await mount(tester, onCommands: (_) => count++);
    queue.requestCommands();
    final pending = fake.controller.readyResult = Completer<Object>();
    fake.controller.navigation.finished('asset');
    await tester.pumpWidget(const SizedBox());
    pending.complete(true);
    fake.controller.reply('<xml/>');
    await tester.pump();
    expect(count, 0);
    expect(
      fake.controller.calls.any((s) => s.startsWith('sendCommandsToFlutter(')),
      false,
    );
    expect(tester.takeException(), null);
  });

  for (final isMaze in [false, true]) {
    testWidgets(
      '${isMaze ? 'maze' : 'scratch'} native wrapper parses returned XML',
      (tester) async {
        var count = 0;
        final scratchKey =
            GlobalKey<scratch.PageGameSteamScratchBlocklyEditorState>();
        final mazeKey =
            GlobalKey<maze.PageGameSteamScratchMazeBlocklyEditorState>();
        await tester.pumpWidget(
          _host(
            isMaze
                ? maze.PageGameSteamScratchMazeBlocklyEditor(
                    key: mazeKey,
                    onCommandsReady: (commands) {
                      expect(commands.length, 1);
                      count++;
                    },
                  )
                : scratch.PageGameSteamScratchBlocklyEditor(
                    key: scratchKey,
                    onCommandsReady: (commands) {
                      expect(commands.length, 1);
                      count++;
                    },
                  ),
          ),
        );
        await tester.pump();
        fake.controller.navigation.finished('asset');
        await tester.pump();
        if (isMaze) {
          await mazeKey.currentState!.requestBlocklyJson();
        } else {
          await scratchKey.currentState!.requestBlocklyJson();
        }
        await tester.pump();
        fake.controller.reply('<xml><block type="forward"></block></xml>');
        expect(count, 1);
      },
    );
  }
}
