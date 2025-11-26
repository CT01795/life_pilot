import 'dart:math';

import 'package:flutter/material.dart';
import 'package:life_pilot/controllers/auth/controller_auth.dart';
import 'package:life_pilot/controllers/game/controller_game_steam_super_hero.dart';
import 'package:life_pilot/controllers/game/controller_game_steam_super_hero_level_generator.dart';
import 'package:life_pilot/core/const.dart';
import 'package:life_pilot/models/game/model_game_steam_super_hero_level.dart';
import 'package:life_pilot/pages/game/steam_super_hero/page_game_steam_super_hero_blockly_editor.dart';
import 'package:life_pilot/services/game/service_game.dart';
import 'package:life_pilot/views/game/widgets_game_steam_super_hero_game_board.dart';
import 'package:provider/provider.dart';

import '../../../core/logger.dart';

class PageGameSteamSuperHero extends StatefulWidget {
  final String gameId;
  final int gameLevel;
  const PageGameSteamSuperHero(
      {super.key, required this.gameId, required this.gameLevel});

  @override
  State<PageGameSteamSuperHero> createState() => _PageGameSteamSuperHeroState();
}

class _PageGameSteamSuperHeroState extends State<PageGameSteamSuperHero> {
  late final ControllerGameSteamSuperHero game;
  late List<Command> commands;

  // ---- Split Panel 狀態 ----
  double editorWidth = 600; // Editor 初始寬度
  final double minEditorWidth = 40;
  final double maxEditorWidth = 600;

  // Editor 的 Key
  final GlobalKey<PageGameSteamSuperHeroBlocklyEditorState> editorKey =
      GlobalKey<PageGameSteamSuperHeroBlocklyEditorState>();

  @override
  void initState() {
    super.initState();

    final level =
        GameSteamSuperHeroLevelGenerator().generateLevel(widget.gameLevel);
    final auth = context.read<ControllerAuth>();

    game = ControllerGameSteamSuperHero(
        gameId: widget.gameId,
        userName: auth.currentAccount ?? AuthConstants.guest,
        service: ServiceGame(),
        level: level);

    // 監聽 game state 更新
    game.stateNotifier.addListener(() {
      if (mounted) setState(() {});
    });

    // 監聽遊戲事件
    game.eventStream.listen((event) async {
      if (mounted) showGameDialog(event);
    });
  }

  @override
  void dispose() {
    game.dispose();
    super.dispose();
  }

  void showGameDialog(GameEvent event) {
    if (event.type == GameEventType.none) return;
    Color bg = switch (event.type) {
      GameEventType.obstacle => Colors.red.shade600, // 柔和紅
      GameEventType.fruit => Colors.orange.shade400, // 柔和橙
      GameEventType.treasure => Colors.green.shade400, // 柔和綠
      GameEventType.complete => Colors.blue.shade400, // 柔和藍
      GameEventType.warning => Colors.red.shade600, // 柔和紅
      GameEventType.none => Colors.white
    };

    // 水果 → 自動 300ms 關閉
    if (event.type == GameEventType.fruit ||
        event.type == GameEventType.warning) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          Future.delayed(
              Duration(
                  milliseconds: event.type == GameEventType.fruit ? 300 : 1500),
              () {
            if (Navigator.of(context).canPop()) Navigator.of(context).pop();
          });

          return Dialog(
            backgroundColor: Colors.transparent,
            child: Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 8,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Text(event.message,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold)),
            ),
          );
        },
      );
      return;
    }

    // ----❗失敗（障礙）→ 顯示重新開始按鈕------
    if (event.type == GameEventType.obstacle) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          return Dialog(
            backgroundColor: Colors.red.shade300, // 柔和紅色
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    event.message,
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold),
                  ),
                  Gaps.h8,
                  // Restart 按鈕
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade100, // 淡紅
                      foregroundColor: Colors.red.shade700,
                      padding:
                          EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: () async {
                      if (!mounted) return;
                      Navigator.of(context).pop(); // 關閉 Dialog
                      await Future.delayed(
                          Duration(milliseconds: 100)); // 等 dialog 關閉完成
                      game.resetGame(); // 重置遊戲
                    },
                    icon: Icon(Icons.refresh, size: 22),
                    label: Text("Restart", style: TextStyle(fontSize: 18)),
                  ),
                  Gaps.h16,
                  // Back 按鈕
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey.shade200, // 淡灰
                      foregroundColor: Colors.black87,
                      padding:
                          EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: () {
                      Navigator.of(context).pop(); // 關閉 Dialog
                      Navigator.of(context, rootNavigator: true)
                          .pop(true); // 回上一頁
                    },
                    icon: Icon(Icons.arrow_back, size: 22),
                    label: Text("Back", style: TextStyle(fontSize: 18)),
                  ),
                ],
              ),
            ),
          );
        },
      );
      return;
    }

    // 其它（例如：寶藏、過關）→ 自動關閉
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        Future.delayed(Duration(seconds: 1), () {
          if (!mounted) return; // widget 已卸載，直接 return
          if (Navigator.of(context).canPop()) Navigator.of(context).pop();
          // ⭐ 回上一頁（通常是 PageGameList）
          Navigator.of(context, rootNavigator: true)
              .pop(true); // 帶回 true → 要求上一頁 refresh
        });

        return Dialog(
          backgroundColor: bg,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Text(event.message,
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold)),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // ---- 1. 計算 maxBlocks ----
    final maxBlocks = game.level.treasure.y +
        game.level.treasure.x +
        game.level.obstacles.length * 2;

    return Scaffold(
      appBar: AppBar(title: Text('Blockly Platform Game')),
      body: Row(
        children: [
          // -----------------------------------------------------------------
          // 左側：Blockly Editor（可收合）
          // -----------------------------------------------------------------
          AnimatedContainer(
            duration: Duration(milliseconds: 180),
            width: editorWidth,
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(right: BorderSide(color: Colors.grey.shade300)),
            ),
            child: Column(
              children: [
                // ---------- Editor Header ----------
                Container(
                  color: Colors.blueGrey.shade700,
                  height: 48,
                  child: Row(
                    children: [
                      Gaps.w8,
                      Expanded(
                        child: Text(
                          "Blockly Editor",
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                      TextButton(
                        onPressed: () async {
                          await editorKey.currentState?.requestBlocklyJson();
                        },
                        child: Text("Start",
                            style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                ),

                // ---------- Editor main ----------
                Expanded(
                  child: PageGameSteamSuperHeroBlocklyEditor(
                    key: editorKey,
                    initialMaxBlocks: maxBlocks,
                    onCommandsReady: (cmds) async {
                      // ✅ 每次開始前重置遊戲
                      game.resetGame(); // 位置、分數、水果全部重置
                      // 延遲 300ms 再回傳
                      await Future.delayed(Duration(milliseconds: 300));

                      commands = cmds;
                      await game.executeCommands(commands);
                    },
                  ),
                ),
              ],
            ),
          ),

          // -----------------------------------------------------------------
          // 右側：遊戲畫面
          // -----------------------------------------------------------------
          Expanded(
            child: Container(
              color: Colors.black,
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 3.0,
                child: LayoutBuilder(builder: (context, constraints) {
                  final topOffset = 60.0; // 分數區高度
                  final availableWidth = constraints.maxWidth;
                  final availableHeight = constraints.maxHeight - topOffset - 10;

                  // 計算整個地圖最大 x/y
                  final maxX = game.level.treasure.x.toInt();
                  final maxY = game.level.treasure.y.toInt();

                  // 每格大小自動計算
                  final tileSize = min(
                    availableWidth / (maxX + 1),
                    availableHeight / (maxY + 1),
                  );

                  return Stack(
                    children: [
                      // 分數區
                      Positioned(
                        top: 0,
                        left: 16,
                        height: topOffset,
                        child: ValueListenableBuilder<GameState>(
                          valueListenable: game.stateNotifier,
                          builder: (context, state, _) {
                            return Text(
                              'Score: ${state.score}',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            );
                          },
                        ),
                      ),

                      // 地圖區
                      Positioned(
                        top: topOffset,
                        left: 0,
                        width: (maxX + 1) * tileSize,
                        height: (maxY + 1) * tileSize,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: SingleChildScrollView(
                            scrollDirection: Axis.vertical,
                            child: SizedBox(
                              width: (maxX + 1) * tileSize,
                              height: (maxY + 1) * tileSize,
                              child: WidgetsGameSteamSuperHeroGameBoard(
                                game: game,
                                tileSize: tileSize, // 傳入自動計算格子大小
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                }),
              )
            ),
          ),
        ],
      ),
    );
  }
}
