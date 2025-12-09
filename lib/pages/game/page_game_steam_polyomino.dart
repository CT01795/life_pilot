import 'dart:math';

import 'package:flutter/material.dart';
import 'package:life_pilot/controllers/auth/controller_auth.dart';
import 'package:life_pilot/controllers/game/controller_game_steam_polyomino.dart';
import 'package:life_pilot/core/const.dart';
import 'package:life_pilot/models/game/model_game_steam_polyomino.dart';
import 'package:life_pilot/services/game/service_game.dart';
import 'package:life_pilot/views/game/widgets_game_steam_polyomino_block.dart';
import 'package:life_pilot/views/game/widgets_game_steam_polyomino_tile.dart';
import 'package:provider/provider.dart';

class GamePage extends StatefulWidget {
  final String gameId;
  final int gameLevel;
  const GamePage({super.key, required this.gameId, required this.gameLevel});

  @override
  State<GamePage> createState() => _GamePageState();
}

class _GamePageState extends State<GamePage> {
  late ControllerGameSteamPolyomino ctrl;
  late List<PolyominoPipeBlock> waiting;

  // --- 統一縮放比例 ---
  double waitingUnit = 42.0; // 初始化
  bool waitingUnitCalculated = false;

  @override
  void initState() {
    super.initState();
    final levelData = PolyominoLevelFactory.generateLevel(widget.gameLevel);
    final auth = context.read<ControllerAuth>();
    ctrl = ControllerGameSteamPolyomino(
      userName: auth.currentAccount ?? AuthConstants.guest,
      service: ServiceGame(),
      gameId: widget.gameId,
      gameLevel: widget.gameLevel, 
      level: levelData);
    waiting = levelData.availableBlocks.map((b) => b.clone()).toList();
    // 初始化時每個水管旋轉一次，強制 build
    for (var b in waiting) {
      b.rotateRight(); // 旋轉一次
      b.rotateRight(); // 如果旋轉一次顯示仍有問題，可以旋轉兩次恢復原方向
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Pipe Path Game"),
        actions: [
          IconButton(
            icon: Icon(Icons.lightbulb_outline),
            onPressed: () {
              setState(() => ctrl.highlightHint());
              Future.delayed(const Duration(seconds: 2), () {
                if (!mounted) return;
                setState(() => ctrl.clearHint());
              });
            },
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, cons) {
          final W = cons.maxWidth;

          return Row(
            children: [
              // 左邊水管區 (40%) -----------
              Container(
                width: W * 0.40,
                padding: const EdgeInsets.all(8),
                alignment: Alignment.topRight,
                child: _buildWaitingArea(cons),
              ),

              // 右邊格子畫布 (60%) -----------
              Container(
                width: W * 0.60,
                padding: const EdgeInsets.all(8),
                child: _buildGridArea(cons),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.check),
        onPressed: () async {
          final ok = await ctrl.isLevelComplete();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(ok ? "🎉 Completed!" : "❌ Not Completed"),
            duration: const Duration(seconds: 1)),
          );
          if (ok) {
            // 延遲 1 秒再回上一頁，讓玩家看到 SnackBar
            Future.delayed(const Duration(seconds: 1), () {
              if (!mounted) return;
              Navigator.pop(context, true); // 過關 -> 返回上一頁
            });
          }
        },
      ),
    );
  }

  Widget _buildWaitingArea(BoxConstraints cons) {
    const padding = 16.0;
    final totalW = cons.maxWidth * 0.4 - padding * 2;
    final totalH = cons.maxHeight - padding * 2;

    if (!waitingUnitCalculated && waiting.isNotEmpty) {
      // 計算統一縮放比例，只做一次
      const baseUnit = 42.0;
      final maxBlockWH = max(waiting.map((b) => b.width).fold(0, max), waiting.map((b) => b.height).fold(0, max));

      final estCols = (maxBlockWH > 0)
          ? (totalW / (maxBlockWH * baseUnit)).floor().clamp(1, waiting.length)
          : 1;
      final estRows = (waiting.length / estCols).ceil();

      final slotW = totalW / estCols;
      final slotH = totalH / estRows;

      final scales = waiting.map((b) {
        return min(slotW / (b.width * baseUnit), slotH / (b.height * baseUnit));
      }).toList();

      waitingUnit = min(baseUnit * scales.reduce(min),80);
      waitingUnitCalculated = true; // 記錄已經計算
    }

    // 如果沒有水管，顯示空白佔位格
    if (waiting.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(padding),
        child: Container(
          width: totalW,
          height: totalH,
          color: Colors.grey.shade200,
          child: const Center(child: Text("No pipes")),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(padding),
      child: Wrap(
        spacing: padding,
        runSpacing: padding,
        alignment: WrapAlignment.center,
        children: waiting.map((b) {
          return Draggable<PolyominoDragBlockData>(
            dragAnchorStrategy: childDragAnchorStrategy,
            data: PolyominoDragBlockData(block: b, source: PolyominoDragSource.waiting),
            feedback: PolyominoBlockWidget(
              block: b,
              unitSize: waitingUnit,
              grid: ctrl.grid,
              showPipe: true,
            ),
            childWhenDragging: const SizedBox.shrink(),
            child: GestureDetector(
              onTap: () {
                setState(() => b.rotateRight());
                // 旋轉時不再重新計算 unitSize
              },
              child: PolyominoBlockWidget(
                block: b,
                unitSize: waitingUnit,
                grid: ctrl.grid,
                showPipe: true,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ---------- 右側格子畫布 ----------
  Widget _buildGridArea(BoxConstraints cons) {
    final rows = ctrl.levelData.rows;
    final cols = ctrl.levelData.cols;

    final maxW = cons.maxWidth * 0.60 - 16;
    final maxH = cons.maxHeight - 32;

    final cell = (rows > 0 && cols > 0) ? min(maxW / cols, maxH / rows) : 50.0;

    return InteractiveViewer(
      minScale: 0.5,
      maxScale: 5.0,
      boundaryMargin: const EdgeInsets.all(100),
      child: Align(
        alignment: Alignment.topLeft, // 靠左對齊
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(rows, (r) {
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(cols, (c) {
                final tile = ctrl.grid[r][c];
                final block = tile.blockId == null
                    ? null
                    : ctrl.placedBlocks.firstWhere((b) => b.id == tile.blockId);

                return DragTarget<PolyominoDragBlockData>(
                  onWillAcceptWithDetails: (details) {
                    return ctrl.canPlaceBlock(details.data.block, c, r);
                  },
                  onAcceptWithDetails: (details) {
                    setState(() {
                      if (!ctrl.placeBlock(details.data.block, c, r)) {
                        if (!waiting.any((w) => w.id == details.data.block.id)) {
                          waiting.add(details.data.block);
                        }
                      } else if (details.data.source == PolyominoDragSource.waiting) {
                        waiting.removeWhere((w) => w.id == details.data.block.id);
                      }
                    });
                  },
                  builder: (_, __, ___) {
                    if (block != null) {
                      return Draggable<PolyominoDragBlockData>(
                        dragAnchorStrategy: childDragAnchorStrategy,
                        data: PolyominoDragBlockData(
                            block: block, source: PolyominoDragSource.grid),
                        feedback: PolyominoBlockWidget(
                          block: block,
                          unitSize: cell,
                          grid: ctrl.grid,
                          showPipe: true,
                        ),
                        childWhenDragging: PolyominoTileWidget(tile: tile, size: cell),
                        onDragStarted: () =>
                            setState(() => ctrl.removeBlock(block)),
                        onDraggableCanceled: (_, __) {
                          if (!waiting.any((w) => w.id == block.id)) {
                            setState(() => waiting.add(block));
                          }
                        },
                        child: PolyominoTileWidget(tile: tile, size: cell),
                      );
                    }
                    return PolyominoTileWidget(tile: tile, size: cell);
                  },
                );
              }),
            );
          }),
        ),
      ),
    );
  }
}
