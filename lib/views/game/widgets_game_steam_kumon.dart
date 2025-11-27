// tile_widget.dart
import 'package:flutter/material.dart';
import 'package:life_pilot/models/game/model_game_steam_kumon.dart';

class TileWidget extends StatelessWidget {
  final Tile tile;
  final Function(TileDirection?) onDropped; // 可以放空值
  final double size;

  const TileWidget({
    super.key,
    required this.tile,
    required this.onDropped,
    required this.size,
  });

  Color _getTileColor() {
    if (tile.isHighlighted) return Colors.yellowAccent;
    if (tile.isStart || tile.isGoal) return Colors.green;
    if (tile.fixed) return Colors.black87; // 障礙
    return Colors.blue[100]!;
  }

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

  Widget? _getIcon() {
    List<Widget> icons = [];

    if (tile.isFixedArrow) {
      icons.add(Icon(_directionToIcon(tile.direction),
          color: Colors.redAccent, size: size * 0.7));
      return Stack(alignment: Alignment.center, children: icons);
    }

    if (tile.isStart) {
      icons.add(Icon(Icons.directions_walk_rounded,
          color: Colors.white, size: size * 0.8));
    }
    if (tile.isGoal) {
      icons.add(
          Icon(Icons.vpn_key_rounded, color: Colors.white, size: size * 0.8));
      return Stack(alignment: Alignment.center, children: icons);
    }
    if (tile.fixed) {
      icons.add(Icon(Icons.block, color: Colors.white, size: size * 0.7));
    }
    if (tile.direction != TileDirection.empty) {
      icons.add(Icon(_directionToIcon(tile.direction),
          size: size * 0.6, color: Colors.black));
    }

    return Stack(alignment: Alignment.center, children: icons);
  }

  @override
  Widget build(BuildContext context) {
    if (tile.fixed) {
      // 固定格子不能拖
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: _getTileColor(),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.black26),
        ),
        child: Center(child: _getIcon()),
      );
    }

    return DragTarget<TileDirection>(
      onAcceptWithDetails: (details) {
        tile.direction = details.data; // 玩家放箭頭
        onDropped(details.data);
      },
      builder: (context, candidateData, rejectedData) {
        Widget content = Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: _getTileColor(),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.black26),
          ),
          child: Center(child: _getIcon()),
        );

        // 如果有箭頭，就可以拖動
        if (tile.direction != TileDirection.empty) {
          return Draggable<TileDirection>(
            data: tile.direction,
            feedback: Material(
              child: Container(
                width: size,
                height: size,
                color: Colors.orange.withValues(alpha: (0.8 * 255.0)),
                child: Center(child: _getIcon()),
              ),
            ),
            childWhenDragging: Container(
              width: size,
              height: size,
              color: Colors.blue[100],
            ),
            onDraggableCanceled: (_, __) {
              onDropped(null);
            },
            onDragCompleted: () {
              // 放回其他格子時，清空自己
              onDropped(null);
            },
            child: content,
          );
        } else {
          return content;
        }
      },
    );
  }
}

// draggable_tile.dart
class DraggableTile extends StatelessWidget {
  final TileDirection direction;

  const DraggableTile({super.key, required this.direction});

  IconData getIcon() {
    switch (direction) {
      case TileDirection.up: return Icons.arrow_upward;
      case TileDirection.down: return Icons.arrow_downward;
      case TileDirection.left: return Icons.arrow_back;
      case TileDirection.right: return Icons.arrow_forward;
      default: return Icons.circle_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Draggable<TileDirection>(
      data: direction,
      feedback: Material(
        child: Container(
          width: 50,
          height: 50,
          color: Colors.orange,
          child: Icon(getIcon(), size: 32),
        ),
      ),
      childWhenDragging: Container(
        width: 50,
        height: 50,
        color: Colors.grey[300],
      ),
      child: Container(
        width: 50,
        height: 50,
        color: Colors.blue[100],
        child: Icon(getIcon(), size: 32),
      ),
    );
  }
}
