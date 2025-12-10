// tile_widget.dart
import 'package:flutter/material.dart';
import 'package:life_pilot/models/game/model_game_steam_kumon.dart';

class TileWidget extends StatelessWidget {
  final KumonTile tile;
  final int row;
  final int col;
  final double size;

  final Function(int row, int col, int? fromRow, int? fromCol, KumonTileDirection? newDir) onDropped;

  const TileWidget({
    super.key,
    required this.tile,
    required this.row,
    required this.col,
    required this.onDropped,
    required this.size,
  });

  IconData _directionToIcon(KumonTileDirection dir) {
    switch (dir) {
      case KumonTileDirection.up:
        return Icons.arrow_upward;
      case KumonTileDirection.down:
        return Icons.arrow_downward;
      case KumonTileDirection.left:
        return Icons.arrow_back;
      case KumonTileDirection.right:
        return Icons.arrow_forward;
      default:
        return Icons.circle_outlined;
    }
  }

  Offset centerDragAnchorStrategy(
    Draggable<Object> draggable, BuildContext context, Offset position) {
    final renderBox = context.findRenderObject() as RenderBox;
    final size = renderBox.size;
    // Offset 從 pointer 轉為 feedback 中心
    return size.center(Offset.zero);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: tile,
      builder: (context, _) {
        return DragTarget<Map<String, dynamic>>(
          onWillAcceptWithDetails: (_) => true, /*(details) {
            // 例如不接受障礙、終點、固定箭頭格子
            return !tile.isObstacle && !tile.isGoalP && !tile.isFixedArrow;
          },*/
          onAcceptWithDetails: (details) {
            final fromRow = details.data['fromRow'] as int?;
            final fromCol = details.data['fromCol'] as int?;
            final direction = details.data['direction'] as KumonTileDirection?;
            
            // 如果來源格子是自己格子，直接 return
            if (fromRow == row && fromCol == col) return;

            onDropped(row, col, fromRow, fromCol, direction);
          },
          builder: (context, candidateData, rejectedData) {
            // 分層 Stack
            List<Widget> stackChildren = [];

            // 中層：固定圖示（起點、終點、障礙）
            if (tile.isStartP) {
              stackChildren.add(
                Icon(Icons.directions_walk_rounded,
                    color: Colors.green, size: size * 0.7),
              );
            } else if (tile.isGoalP) {
              stackChildren.add(
                Icon(Icons.vpn_key_rounded,
                    color: Colors.green, size: size * 0.7),
              );
            } else if (tile.isObstacle) {
              stackChildren.add(
                Icon(Icons.block, color: Colors.black87, size: size * 0.7),
              );
            } else if (tile.isFixedArrow) {
              stackChildren.add(
                Icon(_directionToIcon(tile.direction),
                    color: Colors.redAccent, size: size * 0.7),
              );

            }

            // 上層：箭頭（可拖動）
            if (tile.direction != KumonTileDirection.empty && !tile.isFixedArrow && !tile.isObstacle) {
              stackChildren.add(
                Draggable<Map<String, dynamic>>(
                  data: {
                    'fromRow': row,
                    'fromCol': col,
                    'direction': tile.direction,
                  },
                  feedback: Material(
                    color: Colors.transparent,
                    child: SizedBox(
                      width: size,
                      height: size,
                      child: Icon(
                        _directionToIcon(tile.direction),
                        color: Colors.blue[900],
                        size: size * 0.7,
                      ),
                    ),
                  ),
                  dragAnchorStrategy: centerDragAnchorStrategy,
                  childWhenDragging: Container(),
                  onDragCompleted: () {
                    // 通知 Controller 從格子搬箭頭
                    onDropped(row, col, row, col, null); 
                  },
                  child: SizedBox(
                    width: size,
                    height: size,
                    child: Icon(
                      _directionToIcon(tile.direction),
                      color: Colors.blue[900],
                      size: size * 0.7,
                    ),
                  ),
                ),
              );
            }

            return Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: tile.isHighlighted
                    ? Colors.yellowAccent
                    : (tile.isFixedArrow || tile.isStartP || tile.isGoalP)
                        ? Colors.green[300]
                        : tile.isObstacle
                            ? Colors.black87
                            : Colors.blue[100],
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.black26),
              ),
              child: Stack(
                alignment: Alignment.center,
                fit: StackFit.expand, 
                children: stackChildren,
              ),
            );
          },
        );
      },
    );
  }
}
