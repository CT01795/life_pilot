import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:life_pilot/game/steam_scratch_maze/controller_game_steam_scratch_maze.dart';
import 'package:life_pilot/utils/logger.dart';
import 'package:life_pilot/game/steam_scratch_maze/blockly_parser.dart';
import 'package:webview_flutter/webview_flutter.dart';

class PageGameSteamScratchMazeBlocklyEditor extends StatefulWidget {
  final Function(List<Command>) onCommandsReady;
  const PageGameSteamScratchMazeBlocklyEditor({
    super.key,
    required this.onCommandsReady,
  });

  @override
  State<PageGameSteamScratchMazeBlocklyEditor> createState() =>
      PageGameSteamScratchMazeBlocklyEditorState();
}

class PageGameSteamScratchMazeBlocklyEditorState
    extends State<PageGameSteamScratchMazeBlocklyEditor> {
  late WebViewController controller;
  int? windowMaxBlocksPending;

  @override
  void initState() {
    super.initState();
    logger.i("🌟 IO Editor State 建立成功：$this");
    // Mobile / Desktop 使用 WebView
    controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel(
        "BlocklyCallback",
        onMessageReceived: (msg) {
          final jsonString = msg.message;
          final commands = parseBlocklyJson(jsonDecode(jsonString));
          widget.onCommandsReady(commands);
        },
      )
      ..loadFlutterAsset("assets/blockly/index.html")
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (url) {
            logger.i("🌟 HTML 已載入完成");
            // 確保 JS 函式存在再呼叫
            setMaxBlocks(windowMaxBlocksPending!); // 或你要的數值
          },
        ),
      );
  }

  // ⭐ 父 widget 可以呼叫這個方法來更新 maxBlocks
  Future<void> setMaxBlocks(int value) async {
    logger.i("🌟 IO setMaxBlocks");
    windowMaxBlocksPending = value; // 無論 if
    try {
      if (windowMaxBlocksPending != null) {
        await controller.runJavaScript(
          "setMaxBlocksFromFlutter($windowMaxBlocksPending)",
        );
      }
    } catch (ex) {
      logger.e(ex.toString());
    }
  }

  // Flutter → Web 要求取出 JSON
  Future<void> requestBlocklyJson() async {
    await controller.runJavaScript("sendCommandsToFlutter()");
  }

  @override
  Widget build(BuildContext context) {
    return WebViewWidget(controller: controller);
  }
}
