import 'dart:collection';
import 'dart:math';
import 'dart:ui';

import 'package:life_pilot/game/puzzle_map/model_game_puzzle_map.dart';
import 'package:life_pilot/game/service_game.dart';
import 'package:life_pilot/utils/safe_change_notifier.dart';
import 'package:life_pilot/utils/value_parser.dart';

class ControllerGamePuzzleMap extends SafeChangeNotifier {
  final String userName;
  final ServiceGame service;
  final String gameId;
  final int gameLevel;
  final Random? _random;
  final DateTime Function() _now;
  ModelPuzzleBoard? _board;
  int score = 0;
  int _boardRevision = 0;
  int get boardRevision => _boardRevision;
  int get rowsCount => _board?.rows ?? 0;
  int get colsCount => _board?.cols ?? 0;
  List<ModelGamePuzzlePiece> get pieces => _board?.pieces ?? const [];
  final Map<int, Offset> _dragOffsets = {};
  late final Map<int, Offset> dragOffsets = UnmodifiableMapView(_dragOffsets);
  bool _scoreSaved = false;
  DateTime? _lastNotify;

  ControllerGamePuzzleMap({
    required this.userName,
    required this.service,
    required this.gameId,
    required this.gameLevel,
    Random? random,
    DateTime Function()? now,
  }) : _random = random,
       _now = now ?? DateTime.now;

  void setGridSize(int imgWidth, int imgHeight, int shortSideCount) {
    if (notifierDisposed) return;
    final board = ModelPuzzleBoard.fromImage(
      imgWidth,
      imgHeight,
      shortSideCount,
      random: _random,
    );
    _board = board;
    _boardRevision++;
    _scoreSaved = false;
    score = 0;
    _lastNotify = null;
    _dragOffsets.clear();
    notifyListeners();
  }

  Future<bool> checkResult() async {
    if (notifierDisposed) return false;
    final board = _board;
    if (board == null || !board.isSolved) return false;
    if (_scoreSaved) return true;
    final revision = _boardRevision;
    score = board.completionScore;
    _scoreSaved = true;
    try {
      await service.saveUserGameScore(
        newUserName: userName,
        newScore: parseDoubleValue(score),
        newGameId: gameId,
        newIsPass: true,
      );
    } catch (_) {
      if (notifierDisposed || revision != _boardRevision) return false;
      _scoreSaved = false;
      rethrow;
    }
    return !notifierDisposed && revision == _boardRevision;
  }

  void updateDrag(ModelGamePuzzlePiece piece, Offset delta) {
    if (notifierDisposed ||
        _board?.canMove(piece) != true ||
        !delta.dx.isFinite ||
        !delta.dy.isFinite) {
      return;
    }
    _dragOffsets[piece.currentIndex] =
        (_dragOffsets[piece.currentIndex] ?? Offset.zero) + delta;
    final now = _now();
    if (_lastNotify == null ||
        now.difference(_lastNotify!).inMilliseconds > 16) {
      _lastNotify = now;
      notifyListeners();
    }
  }

  void endDrag(
    ModelGamePuzzlePiece piece,
    double tileWidth,
    double tileHeight,
  ) {
    if (notifierDisposed || _board?.canMove(piece) != true) return;
    final oldIndex = piece.currentIndex;
    final offset = _dragOffsets.remove(oldIndex);
    if (offset == null) return;
    _board!.moveBy(
      piece,
      dx: offset.dx,
      dy: offset.dy,
      tileWidth: tileWidth,
      tileHeight: tileHeight,
    );
    _dragOffsets.remove(piece.currentIndex);
    notifyListeners();
  }
}
