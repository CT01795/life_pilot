import 'dart:convert';
// ignore: deprecated_member_use, avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:ui_web';

import 'package:flutter/material.dart';
// ignore: deprecated_member_use
import 'package:js/js_util.dart' as js_util;
import 'package:life_pilot/controllers/game/steam_supper_hero/controller_game_steam_super_hero.dart';
import 'package:life_pilot/models/game/steam_supper_hero/blockly_parser.dart';

import '../../../core/logger.dart';

class PageGameSteamSuperHeroBlocklyEditor extends StatefulWidget {
  final Function(List<Command>) onCommandsReady;

  const PageGameSteamSuperHeroBlocklyEditor(
      {super.key, required this.onCommandsReady});

  @override
  State<PageGameSteamSuperHeroBlocklyEditor> createState() =>
      PageGameSteamSuperHeroBlocklyEditorState();
}

class PageGameSteamSuperHeroBlocklyEditorState
    extends State<PageGameSteamSuperHeroBlocklyEditor> {
  static html.IFrameElement? iframe;
  static bool _iframeRegistered = false;
  static int? windowMaxBlocksPending;

  @override
  void initState() {
    super.initState();
    logger.i("🌟 Web Editor State 建立成功：$this");
    if (!_iframeRegistered) {
      // ignore: undefined_prefixed_name
      platformViewRegistry.registerViewFactory('blockly-iframe', (int viewId) {
        final frame = html.IFrameElement()
          ..src = 'assets/blockly/index.html'
          ..style.border = 'none'
          ..width = '100%'
          ..height = '100%';
        iframe = frame; // 儲存 reference

        // ✅ 等 iframe load 完再發送 MAX_BLOCKS
        iframe?.onLoad.listen((event) {
          _sendPendingMaxBlocks();
        });

        return frame; // ✅ 回傳非 nullable
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
      if (!mounted) return; // ✅ widget 已卸載就直接 return
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
          if (!mounted) return; // 防止 widget 已卸載
          widget.onCommandsReady(cmds);
        }
      } catch (e, st) {
        logger.e('Error parsing message from iframe: $e\n$st');
      }
    });
  }

  // 更新 maxBlocks
  void setMaxBlocks(int value) {
    logger.i("🌟 Web setMaxBlocks");
    windowMaxBlocksPending = value; // 無論 iframe 是否 ready 都存起來
    if (iframe?.contentWindow != null) {
      _sendPendingMaxBlocks();
    } else {
      // iframe 還沒 ready → 等 onLoad 自動發送
      iframe?.onLoad.listen((event) {
        _sendPendingMaxBlocks();
      });
    }
  }

  void _sendPendingMaxBlocks() {
    if (windowMaxBlocksPending == null) return;
    logger.i("🌟 Web setMaxBlocks sendMaxBlocksToIframe");
    iframe?.contentWindow?.postMessage(
      {'type': 'set_max_blocks', 'maxBlocks': windowMaxBlocksPending},
      '*',
    );
    windowMaxBlocksPending = null;
  }

  // Flutter → Web 要求取出 JSON
  Future<void> requestBlocklyJson() async {
    if (iframe == null) {
      logger.e('iframe == null at requestBlocklyJson');
      return;
    }
    iframe?.contentWindow?.postMessage({'type': 'request_commands'}, '*');
  }

  @override
  Widget build(BuildContext context) {
    return HtmlElementView(viewType: 'blockly-iframe');
  }
}
