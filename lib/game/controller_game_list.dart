import 'package:life_pilot/game/model_game_item.dart';
import 'package:life_pilot/game/model_game_user.dart';
import 'package:life_pilot/game/service_game.dart';
import 'package:life_pilot/utils/safe_change_notifier.dart';

class ControllerGameList extends SafeChangeNotifier {
  final ServiceGame serviceGame;
  final String userName;

  List<ModelGameItem> _games = [];
  final Map<String, Map<String, List<ModelGameItem>>> _gamesByCategory = {};
  List<String> _categories = [];
  final Map<String, List<ModelGameUser>> _userProgressCache = {};
  bool _isDisposed = false;

  bool isLoading = false;

  ControllerGameList({required this.serviceGame, required this.userName});

  List<String> get categories => _categories;
  Map<String, Map<String, List<ModelGameItem>>> get gamesByCategory =>
      _gamesByCategory;

  Future<void> loadGames() async {
    isLoading = true;
    _notifyIfActive();

    try {
      _games = await serviceGame.fetchGames();
      if (_isDisposed) return;
      _gamesByCategory.clear();
      for (var g in _games) {
        _gamesByCategory.putIfAbsent(g.gameType, () => {});
        final gameMap = _gamesByCategory[g.gameType]!;
        gameMap.putIfAbsent(g.gameName, () => []).add(g);
      }
      _categories = _gamesByCategory.keys.toList();
    } finally {
      if (!_isDisposed) {
        isLoading = false;
        _notifyIfActive();
      }
    }
  }

  // 查詢目前使用者的分數紀錄
  Future<List<ModelGameUser>> loadUserProgress(
      String gameType, String gameName) async {
    // 組 key
    final key = '$gameType|$gameName';

    isLoading = true;
    _notifyIfActive();

    try {
      final progress =
          await serviceGame.fetchUserProgress(userName, gameType, gameName);
      if (!_isDisposed) {
        // 存到快取
        _userProgressCache[key] = progress;
      }
      return progress;
    } finally {
      if (!_isDisposed) {
        isLoading = false;
        _notifyIfActive();
      }
    }
  }

  void _notifyIfActive() {
    if (!_isDisposed) notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
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
