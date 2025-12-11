import 'package:flutter/material.dart';
import 'package:life_pilot/models/game/model_game_item.dart';
import 'package:life_pilot/models/game/model_game_user.dart';
import 'package:life_pilot/services/game/service_game.dart';

class ControllerGameList extends ChangeNotifier {
  final ServiceGame serviceGame;
  final String userName;

  List<ModelGameItem> _games = [];
  final Map<String, Map<String, List<ModelGameItem>>> _gamesByCategory = {};
  List<String> _categories = [];
  final Map<String, List<ModelGameUser>> _userProgressCache = {};
  
  bool isLoading = false;

  ControllerGameList({required this.serviceGame, required this.userName});

  List<String> get categories => _categories;
  Map<String, Map<String, List<ModelGameItem>>> get gamesByCategory => _gamesByCategory;

  Future<void> loadGames() async {
    isLoading = true;
    notifyListeners();

    _games = await serviceGame.fetchGames();
    _gamesByCategory.clear();
    for (var g in _games) {
      _gamesByCategory.putIfAbsent(g.gameType, () => {});
      final gameMap = _gamesByCategory[g.gameType]!;
      gameMap.putIfAbsent(g.gameName, () => []).add(g);
    }
    _categories = _gamesByCategory.keys.toList();

    isLoading = false;
    notifyListeners();
  }

  // 查詢目前使用者的分數紀錄
  Future<List<ModelGameUser>> loadUserProgress(String gameType, String gameName) async {
    // 組 key
    final key = '$gameType|$gameName';
    /*if (_userProgressCache.containsKey(key)) {
      return _userProgressCache[key]!;
    }*/

    isLoading = true;
    notifyListeners();

    final progress = await serviceGame.fetchUserProgress(userName, gameType, gameName);
    // 存到快取
    _userProgressCache[key] = progress;

    isLoading = false;
    notifyListeners();
    return progress;
  }

  // 取得使用者已通關的最高等級
  int getHighestPassedLevel(List<ModelGameUser> list) {
    if (list.isEmpty) return 0; // 尚未玩過任何關卡

    // 找到 is_pass = true 的最大 level
    final passed = list.where((e) => e.isPass ?? false).toList();
    if (passed.isEmpty) return 0;

    return passed.map((e) => e.level ?? 0).reduce((a, b) => a > b ? a : b);
  }
}
