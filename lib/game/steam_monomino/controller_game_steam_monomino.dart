import 'dart:math';
import 'package:life_pilot/game/steam_monomino/model_game_steam_monomino.dart';
import 'package:life_pilot/game/service_game.dart';
import 'package:life_pilot/utils/safe_change_notifier.dart';

class ControllerGameSteamMonomino extends SafeChangeNotifier {
  final String userName;
  final ServiceGame service;
  final String gameId;
  final int gameLevel;
  final ModelGameMonominoLevel level;
  late final ModelMonominoSession _session;
  late final List<Point<int>> remainingFixed = List.unmodifiable(
    level.remainingFixed,
  );
  List<EnumMonominoTileDirection> get remainingTiles => _session.remainingTiles;
  int get usedSteps => _session.usedSteps;
  int score = 0;
  bool _scoreSaved = false;
  int _generation = 0;
  int _revision = 0;
  int get boardRevision => _revision;

  ControllerGameSteamMonomino({
    required this.userName,
    required this.service,
    required this.gameId,
    required this.gameLevel,
    ModelGameMonominoLevel? level,
    Random? random,
  }) : level =
           level ??
           ModelGameMonominoLevel(
             levelNumber: gameLevel,
             rows: gameLevel + 5,
             cols: gameLevel + 5,
             random: random,
           ) {
    _session = ModelMonominoSession(this.level);
  }

  void startLevel() => resetLevel();

  void resetLevel() {
    if (notifierDisposed) return;
    _session.reset();
    score = 0;
    _generation++;
    _revision++;
    _scoreSaved = false;
    notifyListeners();
  }

  void placeTile(
    int row,
    int col,
    int? fromRow,
    int? fromCol,
    EnumMonominoTileDirection? to,
  ) {
    if (notifierDisposed || !_session.place(row, col, fromRow, fromCol, to)) {
      return;
    }
    _revision++;
    notifyListeners();
  }

  Future<bool> checkPath() async {
    if (notifierDisposed) return false;
    final ok = level.checkPath(List<Point<int>>.from(remainingFixed));
    if (!ok || _scoreSaved) return ok;
    final generation = _generation;
    final revision = _revision;
    score = _session.completionScore;
    _scoreSaved = true;
    try {
      await service.saveUserGameScore(
        newUserName: userName,
        newScore: score.toDouble(),
        newGameId: gameId,
        newIsPass: true,
      );
    } catch (_) {
      if (notifierDisposed || generation != _generation) return false;
      _scoreSaved = false;
      rethrow;
    }
    return !notifierDisposed && revision == _revision;
  }

  void showHint() {
    if (notifierDisposed) return;
    level.highlightPath(level.getSolutionPath());
    notifyListeners();
  }

  void clearHint() {
    if (notifierDisposed) return;
    level.clearHighlight();
    notifyListeners();
  }

  Map<EnumMonominoTileDirection, int> getRemainingCount() =>
      _session.remainingCounts;
}
