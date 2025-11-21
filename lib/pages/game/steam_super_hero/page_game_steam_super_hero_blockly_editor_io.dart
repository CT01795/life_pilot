import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:life_pilot/controllers/game/controller_game_steam_super_hero.dart';
import 'package:life_pilot/models/game/blockly/blockly_parser.dart';
import 'package:webview_flutter/webview_flutter.dart';

class PageGameSteamSuperHeroBlocklyEditor extends StatefulWidget {
  final Function(List<Command>) onCommandsReady;
  final int maxBlocks;

  const PageGameSteamSuperHeroBlocklyEditor({super.key, required this.onCommandsReady, required this.maxBlocks});

  @override
  State<PageGameSteamSuperHeroBlocklyEditor> createState() => PageGameSteamSuperHeroBlocklyEditorState();
}

class PageGameSteamSuperHeroBlocklyEditorState extends State<PageGameSteamSuperHeroBlocklyEditor> {
  late WebViewController controller;

  @override
  void initState() {
    super.initState();
    // Mobile / Desktop 使用 WebView
    controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..loadFlutterAsset("assets/blockly/index.html")
      ..addJavaScriptChannel(
        "BlocklyCallback",
        onMessageReceived: (msg) {
          final jsonString = msg.message;
          final commands = parseBlocklyJson(jsonDecode(jsonString));
          widget.onCommandsReady(commands);
        },
      );
    // 傳 maxBlocks 到 WebView
    controller.runJavaScript(
      'window.postMessage({type: "set_max_blocks", maxBlocks: $widget.maxBlocks}, "*");'
    );
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
