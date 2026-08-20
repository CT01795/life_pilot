import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/game/steam_polyomino/model_game_steam_polyomino.dart';

void main() {
  test('generated polyomino levels always contain a valid path', () {
    for (var level = 0; level <= 30; level++) {
      for (var attempt = 0; attempt < 10; attempt++) {
        final data = ModelGamePolyominoLevelFactory.generateLevel(level);

        expect(data.path.first, data.start);
        expect(data.path.last, data.goal);
        expect(data.path.toSet().length, data.path.length);

        for (var index = 0; index < data.path.length; index++) {
          final cell = data.path[index];
          expect(cell.x, inInclusiveRange(0, data.cols - 1));
          expect(cell.y, inInclusiveRange(0, data.rows - 1));

          if (index == 0) continue;
          final previous = data.path[index - 1];
          final distance =
              (cell.x - previous.x).abs() + (cell.y - previous.y).abs();
          expect(distance, 1);
        }
      }
    }
  });
}
