// tile_widget.dart
import 'package:flutter/material.dart';
import 'package:life_pilot/models/game/model_game_steam_polyomino.dart';

class TileWidget extends StatelessWidget {
  final Tile tile;
  final double size;
  const TileWidget({super.key, required this.tile, required this.size});

  @override
  Widget build(BuildContext context) {
    // ⭐ 如果是 Hint 且有方向 → 顯示 Hint block 的管線
    if (tile.highlight && tile.hintDirs != null) {
      return Container(
        width: size,
        height: size,
        color: Colors.orange.withValues(alpha: 0.3), // Hint 底色
        child: CustomPaint(
          painter: PipePainter(
            tile.hintDirs![0],
            tile.hintDirs![1],
            tile.hintDirs![2],
            tile.hintDirs![3],
            color: Colors.orange,
            thickness: 6,
          ),
        ),
      );
    }

    // ⭐ 一般 tile（畫真正放置的 pipe）
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: _tileColor(),
        border: Border.all(color: Colors.black12),
      ),
      child: (tile.type == TileType.pipe)
          ? CustomPaint(
              painter: PipePainter(
                tile.up,
                tile.right,
                tile.down,
                tile.left,
              ),
            )
          : const SizedBox.shrink(),
    );
  }

  Color _tileColor() {
    switch (tile.type) {
      case TileType.start:
        return Colors.green;
      case TileType.goal:
        return Colors.red;
      default:
        return Colors.grey.shade200;
    }
  }
}

class PipePainter extends CustomPainter {
  final bool up, right, down, left;
  final Color color;
  final double thickness;
  PipePainter(this.up, this.right, this.down, this.left, {
    this.color = Colors.orange,
    this.thickness = 6,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = thickness
      ..strokeCap = StrokeCap.round;

    final cx = size.width / 2;
    final cy = size.height / 2;

    if (up) canvas.drawLine(Offset(cx, 0), Offset(cx, cy), paint);
    if (down) canvas.drawLine(Offset(cx, cy), Offset(cx, size.height), paint);
    if (left) canvas.drawLine(Offset(0, cy), Offset(cx, cy), paint);
    if (right) canvas.drawLine(Offset(cx, cy), Offset(size.width, cy), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}