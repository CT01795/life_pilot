// tile_widget.dart
import 'package:flutter/material.dart';
import 'package:life_pilot/models/game/model_game_steam_polyomino.dart';

class PolyominoTileWidget extends StatelessWidget {
  final PolyominoTile tile;
  final double size;
  const PolyominoTileWidget({super.key, required this.tile, required this.size});

  @override
  Widget build(BuildContext context) {
    Color bg = _tileColor();
    // ⭐ 如果是 Hint 且有方向 → 顯示 Hint block 的管線
    if (tile.highlight && tile.hintDirs != null) {
      return Container(
        width: size,
        height: size,
        color: Colors.orange.withValues(alpha: 0.3), // Hint 底色
        child: CustomPaint(
          painter: PolyominoPipePainter(
            tile.hintDirs![0],
            tile.hintDirs![1],
            tile.hintDirs![2],
            tile.hintDirs![3],
            color:const Color(0xFF2D6EDB),
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
        color: tile.highlight
            ? const Color(0xFFCCE2FF) // 淡藍提示背景
            : bg,
        border: Border.all(color: const Color(0xFFCCCCCC)),
      ),
      child: (tile.type == PolyominoTileType.pipe)
          ? CustomPaint(
              painter: PolyominoPipePainter(
                tile.up,
                tile.right,
                tile.down,
                tile.left,
                color: const Color(0xFF4A90E2),
                thickness:6,
              ),
            )
          : const SizedBox.shrink(),
    );
  }

  Color _tileColor() {
    switch (tile.type) {
      case PolyominoTileType.start:
        return const Color(0xFF6FCF97); // 綠
      case PolyominoTileType.goal:
        return const Color(0xFFEB5757); // 紅
      case PolyominoTileType.pipe:
        return const Color(0xFFE3E7EF); // 藍灰管道底色
      default:
        return const Color(0xFFF4F4F7); // 空格
    }
  }
}

class PolyominoPipePainter extends CustomPainter {
  final bool up, right, down, left;
  final Color color;
  final double thickness;
  PolyominoPipePainter(this.up, this.right, this.down, this.left, {
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