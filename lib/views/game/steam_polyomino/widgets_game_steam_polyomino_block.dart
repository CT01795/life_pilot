import 'package:flutter/material.dart';
import 'package:life_pilot/models/game/model_game_steam_polyomino.dart';
import 'package:life_pilot/views/game/steam_polyomino/widgets_game_steam_polyomino_tile.dart';

class PolyominoBlockWidget extends StatelessWidget {
  final ModelGamePolyominoPipeBlock block;
  final double unitSize;
  final List<List<ModelGamePolyominoTile>> grid; // 用來查 tile 的方向
  final bool showPipe; // 是否顯示水管（待用區=false，格子上=true）

  const PolyominoBlockWidget({
    super.key,
    required this.block,
    required this.unitSize,
    required this.grid,
    required this.showPipe,
  });

 @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: block.width * unitSize,
      height: block.height * unitSize,
      child: Stack(
        children: List.generate(block.cells.length, (i) {
          final c = block.cells[i];
          return Positioned(
            left: c.x * unitSize,
            top: c.y * unitSize,
            child: Container(
              width: unitSize,
              height: unitSize,
              decoration: BoxDecoration(
                color: const Color(0xFFE3E7EF),
                border: Border.all(color: const Color(0xFFCCCCCC)),
              ),
              child: showPipe
                  ? CustomPaint(
                      painter: PolyominoPipePainter(
                        block.connections[i][0],
                        block.connections[i][1],
                        block.connections[i][2],
                        block.connections[i][3],
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          );
        }),
      ),
    );
  }
}
