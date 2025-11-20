import 'dart:convert';
// ignore: deprecated_member_use, avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:ui_web';

import 'package:flutter/material.dart';
// ignore: deprecated_member_use
import 'package:js/js_util.dart' as js_util;
import 'package:life_pilot/controllers/game/controller_game_steam_super_hero.dart';
import 'package:life_pilot/models/game/blockly/blockly_parser.dart';

import '../../../core/logger.dart';

class PageGameSteamSuperHeroBlocklyEditor extends StatefulWidget {
  final Function(List<Command>) onCommandsReady;

  const PageGameSteamSuperHeroBlocklyEditor({super.key, required this.onCommandsReady});

  @override
  State<PageGameSteamSuperHeroBlocklyEditor> createState() => PageGameSteamSuperHeroBlocklyEditorState();
}

class PageGameSteamSuperHeroBlocklyEditorState extends State<PageGameSteamSuperHeroBlocklyEditor> {
  html.IFrameElement? iframe;
  static bool _iframeRegistered = false;

  @override
  void initState() {
    super.initState();
    if (!_iframeRegistered) {
      // ignore: undefined_prefixed_name
      platformViewRegistry.registerViewFactory('blockly-iframe', (int viewId) {
      final frame = html.IFrameElement()
          ..src = 'assets/blockly/index.html'
          ..style.border = 'none'
          ..width = '100%'
          ..height = '100%';
        iframe = frame;       // 儲存 reference
        return frame;         // ✅ 回傳非 nullable
      });
      _iframeRegistered = true;
    }
    // 註冊 iframe
    // ignore: undefined_prefixed_name
    // 如果這裡還報錯，代表你的 Flutter 版本不支援直接註冊，需要用 `package:flutter_web_plugins/flutter_web_plugins.dart`
    // import 'package:flutter_web_plugins/flutter_web_plugins.dart' as web_plugins;
    // web_plugins.platformViewRegistry.registerViewFactory(...);
    // 建議這種方式
    html.window.onMessage.listen((event) {
      try {
        final dynamic data = event.data;
        Map<String, dynamic> msg;

        if (data is String) {
          msg = jsonDecode(data) as Map<String, dynamic>;
        } else {
          // 使用 dart:js_util 安全取得 JS Object 的 key
          msg = {};
          final keys = js_util.getProperty(data, 'keys') ?? (data as Map).keys;
          for (var key in keys) {
            msg[key.toString()] = js_util.getProperty(data, key);
          }
        }

        if (msg['type'] == 'commands_ready') {
          final cmds = parseBlocklyJson(jsonDecode(msg['json'] as String));
          widget.onCommandsReady(cmds);
        }
      } catch (e, st) {
        logger.e('Error parsing message from iframe: $e\n$st');
      }
    });
  }

  // Flutter → Web 要求取出 JSON
  Future<void> requestBlocklyJson() async {
    iframe?.contentWindow?.postMessage({'type': 'request_commands'}, '*');
  }

  @override
  Widget build(BuildContext context) {
    return HtmlElementView(viewType: 'blockly-iframe');
  }
}
