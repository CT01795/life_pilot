import 'dart:math';

import 'package:flutter/material.dart';
import 'package:life_pilot/controllers/auth/controller_auth.dart';
import 'package:life_pilot/controllers/game/controller_game_steam_kumon.dart';
import 'package:life_pilot/core/const.dart';
import 'package:life_pilot/models/game/model_game_steam_kumon.dart';
import 'package:life_pilot/pages/game/page_game_word_match.dart';
import 'package:life_pilot/services/game/service_game.dart';
import 'package:life_pilot/views/game/widgets_game_steam_kumon.dart';
import 'package:provider/provider.dart';

class PageGameSteamKumon extends StatefulWidget {
  final String gameId;
  final int gameLevel;
  const PageGameSteamKumon(
      {super.key, required this.gameId, required this.gameLevel});

  @override
  State<PageGameSteamKumon> createState() => _PageGameSteamKumonState();
}

class _PageGameSteamKumonState extends State<PageGameSteamKumon> {
  late ControllerGameSteamKumon controller;

  @override
  void initState() {
    super.initState();
    final auth = context.read<ControllerAuth>();
    controller = ControllerGameSteamKumon(
        userName: auth.currentAccount ?? AuthConstants.guest,
        service: ServiceGame(),
        gameId: widget.gameId,
        gameLevel: widget.gameLevel);
  }

  void _checkPath() async {
    bool ok = await controller.checkPath();
    setState(() {}); // 更新分數

    // 顯示結果
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(ok ? "Pass！🎉" : "Fail 😢"),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              if (ok) {
                // 強制跳轉到 WordMatch 遊戲頁（不能跳過）
                final result = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(
                    builder: (context) => PageGameWordMatch(
                      gameId: widget.gameId,
                      gameLevel: widget.gameLevel,
                    ),
                  ),
                );
                if (result == true) {
                  // 延遲 1 秒再回上一頁，讓玩家看到 SnackBar
                  Future.delayed(const Duration(seconds: 1), () {
                    if (!mounted) return;
                    Navigator.pop(context, true); // 過關 -> 返回上一頁
                  });
                }
              }
            },
            child: Text("OK"),
          )
        ],
      ),
    );
  }

  final Map<KumonTileDirection, IconData> arrowIcons = {
    KumonTileDirection.up: Icons.arrow_upward,
    KumonTileDirection.down: Icons.arrow_downward,
    KumonTileDirection.left: Icons.arrow_back,
    KumonTileDirection.right: Icons.arrow_forward,
    KumonTileDirection.empty: Icons.circle_outlined,
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("KUMON"),
      ),
      body: Column(
        children: [
          Gaps.h8,
          Padding(
            padding: const EdgeInsets.only(left: 20),
            child: Row(
              children: [
                ElevatedButton(
                  onPressed: _checkPath,
                  child: Text("Check the path"),
                ),
                Gaps.w16,
                if(controller.usedSteps > 20)
                  ElevatedButton(
                    onPressed: () async {
                      controller.showHint();
                      setState(() {});
                      await Future.delayed(Duration(seconds: 2));
                      controller.clearHint();
                      setState(() {});
                    },
                    child: Text("Hint 💡"),
                  ),
              ],
            ),
          ),
          Gaps.h16,
          // 本關給的積木
          Padding(
            padding: const EdgeInsets.only(left: 20),
            child: SizedBox(
              height: 50,
              child: AnimatedBuilder(
                animation: controller, // ← 監聽 Controller
                builder: (context, _) {
                  final counts = controller.getRemainingCount();
                  return Row(
                    children: counts.entries.map((e) {
                      KumonTileDirection dir = e.key;
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6.0),
                        child: Draggable<Map<String, dynamic>>(
                          data: {
                            'fromRow': null,
                            'fromCol': null,
                            'direction': dir,
                          },
                          feedback: Material(
                            child: Chip(
                              padding: EdgeInsets.zero,
                              label: Icon(arrowIcons[dir], size: 16),
                              backgroundColor: Colors.orange[300],
                            ),
                          ),
                          childWhenDragging: SizedBox(
                            width: 85,
                            child: Chip(
                              padding: EdgeInsets.all(2),
                              labelPadding: EdgeInsets.zero,
                              label: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(arrowIcons[dir], size: 18),
                                  SizedBox(width: 4),
                                  Text(
                                    "${counts[dir] ?? 0}",
                                    style: TextStyle(fontSize: 16),
                                  ),
                                ],
                              ),
                              backgroundColor: Colors.grey[300],
                            ),
                          ),
                          child: SizedBox(
                            width: 85,
                            child: Chip(
                              padding: EdgeInsets.all(2),
                              labelPadding: EdgeInsets.zero,
                              label: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(arrowIcons[dir], size: 22),
                                  SizedBox(width: 4),
                                  Text(
                                    "${counts[dir] ?? 0}",
                                    style: TextStyle(fontSize: 18),
                                  ),
                                ],
                              ),
                              backgroundColor: Colors.blue[200],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
            ),
          ),
          Gaps.h8,
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                double maxW = constraints.maxWidth - 40;
                double maxH = constraints.maxHeight - 40;

                int rows = controller.level.rows;
                int cols = controller.level.cols;

                // 格子大小
                double tileSize = min(maxW / cols, maxH / rows);

                // 整個棋盤尺寸
                double gridW = tileSize * cols;
                double gridH = tileSize * rows;

                return Padding(
                    padding: const EdgeInsets.fromLTRB(
                        20, 0, 20, 20), // 左16、上0、右16、下16
                    child: Align(
                      alignment: Alignment.topLeft, // 畫布靠上靠左
                      child: InteractiveViewer(
                        panEnabled: true, // 可以拖動
                        scaleEnabled: true, // 可以縮放
                        minScale: 0.5, // 最小縮放
                        maxScale: 3.0, // 最大縮放
                        child: SizedBox(
                          width: gridW,
                          height: gridH,
                          child: GridView.builder(
                            physics: NeverScrollableScrollPhysics(),
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: cols,
                              childAspectRatio: 1,
                            ),
                            itemCount: rows * cols,
                            itemBuilder: (context, index) {
                              int r = index ~/ cols;
                              int c = index % cols;
                              return TileWidget(
                                tile: controller.level.board[r][c],
                                row: r,
                                col: c,
                                onDropped:
                                    (row, col, fromRow, fromCol, newDir) {
                                  controller.placeTile(
                                      row, col, fromRow, fromCol, newDir);
                                },
                                size: tileSize,
                              );
                            },
                          ),
                        ),
                      ),
                    ));
              },
            ),
          ),
        ],
      ),
    );
  }
}
