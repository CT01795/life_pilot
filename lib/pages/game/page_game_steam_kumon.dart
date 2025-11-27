import 'dart:math';

import 'package:flutter/material.dart';
import 'package:life_pilot/controllers/auth/controller_auth.dart';
import 'package:life_pilot/controllers/game/controller_game_steam_kumon.dart';
import 'package:life_pilot/core/const.dart';
import 'package:life_pilot/models/game/model_game_steam_kumon.dart';
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
  int usedSteps = 0; // 新增計數器

  @override
  void initState() {
    super.initState();
    final auth = context.read<ControllerAuth>();
    controller = ControllerGameSteamKumon(userName: auth.currentAccount ?? AuthConstants.guest, service: ServiceGame(), gameId: widget.gameId, gameLevel: widget.gameLevel);
  }

  void _checkPath() async {
    bool ok = await controller.checkPath(usedSteps);
    setState(() {}); // 更新分數
    if(ok) usedSteps = 0; // 過關後重置
    
    // 顯示結果
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(ok ? "Pass！🎉" : "Fail 😢"),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              // 過關 -> 寫入資料庫
              if (!ok) {
                controller.resetLevel();
              }
              else{
                Navigator.pop(context, true); // 過關 -> 返回上一頁
              }
              setState(() {});
            },
            child: Text("OK"),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("KUMON"),
      ),
      body: Column(
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("Score: ${controller.score}", style: TextStyle(fontSize: 20)),
              Gaps.w8,
              ElevatedButton(
                onPressed: _checkPath,
                child: Text("Check the path"),
              ),
            ],
          
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                double maxW = constraints.maxWidth;
                double maxH = constraints.maxHeight;

                int rows = controller.level.rows;
                int cols = controller.level.cols;

                // 格子大小
                double tileSize = min(maxW / cols, maxH / rows);

                // 整個棋盤尺寸
                double gridW = tileSize * cols;
                double gridH = tileSize * rows;

                return Center(
                  child: SizedBox(
                    width: gridW,
                    height: gridH,
                    child: GridView.builder(
                      physics: NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: cols,
                        childAspectRatio: 1,
                      ),
                      itemCount: rows * cols,
                      itemBuilder: (context, index) {
                        int r = index ~/ cols;
                        int c = index % cols;

                        return TileWidget(
                          tile: controller.level.board[r][c],
                          onDropped: (dir) {
                            setState(() {
                              controller.placeTile(r, c, dir);
                              usedSteps++;
                            });
                          },
                          size: tileSize,
                        );
                      },
                    ),
                  ),
                );
              },
            ),
          ),
          Gaps.h8,
          // 本關給的積木（正確 + 假箭頭混合）
          Wrap(
            children: controller.remainingTiles
                .map((dir) => DraggableTile(direction: dir))
                .toList(),
          ),
        ],
      ),
    );
  }
}