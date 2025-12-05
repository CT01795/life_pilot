import 'package:flutter/material.dart';
import 'package:life_pilot/models/game/model_game_steam_polyomino.dart';
import 'package:life_pilot/views/game/widgets_game_steam_polyomino_tile.dart';

class BlockWidget extends StatelessWidget {
  final PipeBlock block;
  final double unitSize;
  final List<List<Tile>> grid; // 用來查 tile 的方向
  final bool showPipe; // 是否顯示水管（待用區=false，格子上=true）

  const BlockWidget({
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
                color: Colors.grey.shade400,
                border: Border.all(
                  color: Colors.black38, // cell 格線顏色
                  width: 1.0,            // 格線粗細
                ),
              ),
              child: showPipe
                  ? CustomPaint(
                      painter: PipePainter(
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
