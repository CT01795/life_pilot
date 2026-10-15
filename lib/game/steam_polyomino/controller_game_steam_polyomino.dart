import 'package:life_pilot/game/steam_polyomino/model_game_steam_polyomino.dart';
import 'package:life_pilot/game/steam_polyomino/model_polyomino_board.dart';
import 'package:life_pilot/game/service_game.dart';
import 'package:life_pilot/utils/safe_change_notifier.dart';

class ControllerGameSteamPolyomino extends SafeChangeNotifier {
  final String userName;
  final ServiceGame service;
  final String gameId;
  final int gameLevel;
  final ModelGamePolyominoLevelData levelData;
  final ModelPolyominoBoard _board;
  List<List<ModelGamePolyominoTile>> get grid => _board.grid;
  List<ModelGamePolyominoPipeBlock> get placedBlocks => _board.placedBlocks;
  int get boardRevision => _board.revision;
  bool _scoreSaved = false;

  ControllerGameSteamPolyomino({
    required this.userName,
    required this.service,
    required this.gameId,
    required this.gameLevel,
    required ModelGamePolyominoLevelData level,
  }) : levelData = level,
       _board = ModelPolyominoBoard(level);

  ModelGamePolyominoPipeBlock? blockById(int id) => _board.blockById(id);

  bool canPlaceBlock(ModelGamePolyominoPipeBlock block, int gx, int gy) =>
      !notifierDisposed && _board.canPlaceBlock(block, gx, gy);

  bool placeBlock(ModelGamePolyominoPipeBlock block, int gx, int gy) {
    if (notifierDisposed || !_board.placeBlock(block, gx, gy)) return false;
    notifyListeners();
    return true;
  }

  void removeBlock(ModelGamePolyominoPipeBlock block) {
    if (!notifierDisposed && _board.removeBlock(block)) notifyListeners();
  }

  Future<bool> isLevelComplete() async {
    if (notifierDisposed || !_board.isComplete) return false;
    if (_scoreSaved) return true;
    final revision = boardRevision;
    _scoreSaved = true;
    try {
      await service.saveUserGameScore(
        newUserName: userName,
        newScore: levelData.availableBlocks.length * 10,
        newGameId: gameId,
        newIsPass: true,
      );
    } catch (_) {
      if (notifierDisposed) return false;
      _scoreSaved = false;
      if (revision != boardRevision) return false;
      rethrow;
    }
    return !notifierDisposed && revision == boardRevision;
  }

  void highlightHint() {
    if (notifierDisposed) return;
    _board.highlightHint();
    notifyListeners();
  }

  void clearHint() {
    if (notifierDisposed) return;
    _board.clearHint();
    notifyListeners();
  }
}
