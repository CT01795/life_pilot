// tile_widget.dart
import 'package:flutter/material.dart';
import 'package:life_pilot/models/game/model_game_steam_kumon.dart';

class TileWidget extends StatelessWidget {
  final Tile tile;
  final int row;
  final int col;
  final double size;
  final Function(TileDirection?) onDropped; // 可以放空值

  const TileWidget({
    super.key,
    required this.tile,
    required this.row,
    required this.col,
    required this.onDropped,
    required this.size,
  });

  IconData _directionToIcon(TileDirection dir) {
    switch (dir) {
      case TileDirection.up:
        return Icons.arrow_upward;
      case TileDirection.down:
        return Icons.arrow_downward;
      case TileDirection.left:
        return Icons.arrow_back;
      case TileDirection.right:
        return Icons.arrow_forward;
      default:
        return Icons.circle_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: tile,
      builder: (context, _) {
        return DragTarget<TileDirection>(
          onWillAcceptWithDetails: (details) {
            // 例如不接受障礙、終點、固定箭頭格子
            return !tile.isObstacle && !tile.isGoalP && !tile.isFixedArrow;
          },
          onAcceptWithDetails: (details) {
            onDropped(details.data); // 由 Controller 更新狀態
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
            if (tile.direction != TileDirection.empty && !tile.isFixedArrow && !tile.isObstacle) {
              stackChildren.add(
                Draggable<TileDirection>(
                  data: tile.direction,
                  feedback: Material(
                    child: Icon(
                      _directionToIcon(tile.direction),
                      color: Colors.blue[900],
                      size: size * 0.7,
                    ),
                  ),
                  childWhenDragging: Container(),
                  onDragCompleted: () => onDropped(null),
                  child: Icon(
                    _directionToIcon(tile.direction),
                    color: Colors.blue[900],
                    size: size * 0.7,
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
                children: stackChildren,
              ),
            );
          },
        );
      },
    );
  }
}
