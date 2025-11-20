import 'package:flutter/material.dart';
import 'package:life_pilot/controllers/auth/controller_auth.dart';
import 'package:life_pilot/controllers/game/controller_game_steam_super_hero.dart';
import 'package:life_pilot/controllers/game/controller_game_steam_super_hero_level_generator.dart';
import 'package:life_pilot/core/const.dart';
import 'package:life_pilot/pages/game/page_game_steam_super_hero_blockly_editor.dart';
import 'package:life_pilot/services/game/service_game.dart';
import 'package:life_pilot/views/game/widgets_game_steam_super_hero_game_board.dart';
import 'package:provider/provider.dart';

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
  double editorWidth = 450; // Editor 初始寬度
  bool editorCollapsed = false; // 是否收合
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

    // ⭐ 畫面更新
    game.setUpdateCallback(() {
      if (mounted) setState(() {});
    });

    // ⭐ 顯示事件訊息
    game.setEventCallback((event) {
      _showGameMessage(event);
    });
  }

  void _showGameMessage(GameEvent event) {
    Color bg = switch (event.type) {
      GameEventType.obstacle => Colors.red,
      GameEventType.fruit => Colors.orange,
      GameEventType.treasure => Colors.green,
      GameEventType.complete => Colors.blue,
    };

    // 水果 → 自動 300ms 關閉
    if (event.type == GameEventType.fruit) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          Future.delayed(Duration(milliseconds: 300), () {
            if (Navigator.of(context).canPop()) Navigator.of(context).pop();
          });

          return Dialog(
            backgroundColor: Colors.transparent,
            child: Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(event.message,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white, fontSize: 22)),
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
            backgroundColor: Colors.red.shade700,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    event.message,
                    style: TextStyle(color: Colors.white, fontSize: 24),
                  ),
                  Gaps.h8,
                  // ---------------------- Restart ----------------------
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.red,
                    ),
                    onPressed: () {
                      Navigator.of(context).pop(); // 關閉 dialog
                      game.resetGame();            // ⭐ 重設遊戲
                    },
                    child: Text("Restart", style: TextStyle(fontSize: 22)),
                  ),
                  Gaps.h8,
                  // ---------------------- Back ----------------------
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black87,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () {
                      Navigator.of(context).pop(); // 關閉 dialog

                      // ⭐ 回上一頁（通常是 PageGameList）
                      Navigator.of(context).pop(true);    // 帶回 true → 要求上一頁 refresh
                    },
                    child: Text("Back", style: TextStyle(fontSize: 22)),
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
          if (Navigator.of(context).canPop()) Navigator.of(context).pop();
          // ⭐ 回上一頁（通常是 PageGameList）
          Navigator.of(context).pop(true);    // 帶回 true → 要求上一頁 refresh
        });

        return Dialog(
          backgroundColor: bg,
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Text(event.message,
                style: TextStyle(color: Colors.white, fontSize: 22)),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Blockly Platform Game')),
      body: Row(
        children: [
          // -----------------------------------------------------------------
          // 左側：Blockly Editor（可收合）
          // -----------------------------------------------------------------
          AnimatedContainer(
            duration: Duration(milliseconds: 180),
            width: editorCollapsed ? minEditorWidth : editorWidth,
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
                      // 收合 / 展開按鈕（改成較小寬度避免 overflow）
                      SizedBox(
                        width: 30, // 🌟 取代 IconButton，避免最小寬度 48px
                        child: InkWell(
                          child: Icon(
                            editorCollapsed ? Icons.arrow_right : Icons.arrow_left,
                            color: Colors.white,
                            size: 50,
                          ),
                          onTap: () {
                            setState(() {
                              editorCollapsed = !editorCollapsed;
                            });
                          },
                        ),
                      ),

                      if (!editorCollapsed) ...[
                        Gaps.w8,
                        Expanded(
                          child: Text(
                            "Blockly Editor",
                            style: TextStyle(color: Colors.white),
                          ),
                        ),

                        TextButton(
                          onPressed: () async {
                            if (editorCollapsed) return; // 或先展開
                            await editorKey.currentState?.requestBlocklyJson();
                          },
                          child: Text("Start", style: TextStyle(color: Colors.white)),
                        ),
                      ],
                    ],
                  ),
                ),

                // ---------- Editor main ----------
                Expanded(
                  child: AnimatedSwitcher(
                    duration: Duration(milliseconds: 150),
                    child: editorCollapsed
                        ? SizedBox() // 收合時完全不渲染 blockly iframe
                        : PageGameSteamSuperHeroBlocklyEditor(
                            key: editorKey, // 保證重新建立避免 cache
                            onCommandsReady: (cmds) async {
                              setState(() => commands = cmds);
                              await game.executeCommands(commands);
                            },
                          ),
                  ),
                ),
              ],
            ),
          ),

          // -----------------------------------------------------------------
          // SplitBar：拖曳中間的 Bar 調整 Editor 寬度
          // -----------------------------------------------------------------
          MouseRegion(
            cursor: SystemMouseCursors.resizeLeftRight,
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onPanUpdate: (details) {
                if (editorCollapsed) return; // 收合時不能拉
                setState(() {
                  editorWidth += details.delta.dx;
                  editorWidth =
                      editorWidth.clamp(minEditorWidth, maxEditorWidth);
                });
              },
              child: Container(
                width: 6,
                color: Colors.grey.shade300,
              ),
            ),
          ),

          // -----------------------------------------------------------------
          // 右側：遊戲畫面
          // -----------------------------------------------------------------
          Expanded(
            child: Container(
              color: Colors.black,
              child: Center(
                child: WidgetsGameSteamSuperHeroGameBoard(game: game),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
