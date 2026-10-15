import 'package:life_pilot/game/model_game_catalog.dart';
import 'package:life_pilot/game/model_game_item.dart';
import 'package:life_pilot/game/service_game.dart';
import 'package:life_pilot/utils/safe_change_notifier.dart';

/// Loads the catalog; play history belongs to ControllerGameProgress.
class ControllerGameList extends SafeChangeNotifier {
  ControllerGameList({required this.serviceGame});

  final ServiceGame serviceGame;
  ModelGameCatalog _catalog = ModelGameCatalog(const []);
  Future<void>? _loadRequest;
  bool _isLoading = false;
  Object? _loadError;

  bool get isLoading => _isLoading;
  Object? get loadError => _loadError;
  List<String> get categories => _catalog.categories;
  Map<String, Map<String, List<ModelGameItem>>> get gamesByCategory =>
      _catalog.gamesByCategory;
  ModelGameItem? get firstGame => _catalog.firstGame;

  ModelGameItem? findGame({String? gameType, String? gameName, int? level}) =>
      _catalog.findGame(gameType: gameType, gameName: gameName, level: level);

  /// Concurrent callers share one request. A later explicit load still refreshes.
  Future<void> loadGames() {
    if (notifierDisposed) return Future.value();
    final active = _loadRequest;
    if (active != null) return active;
    final source = Future<List<ModelGameItem>>.sync(serviceGame.fetchGames);
    final request = _applyCatalog(source);
    _loadRequest = request;
    _isLoading = true;
    _loadError = null;
    notifyListeners();
    return request;
  }

  Future<void> _applyCatalog(Future<List<ModelGameItem>> source) async {
    try {
      final games = await source;
      if (notifierDisposed) return;
      _catalog = ModelGameCatalog(games);
    } catch (error) {
      if (!notifierDisposed) {
        _loadError = error;
        rethrow;
      }
    } finally {
      _loadRequest = null;
      if (!notifierDisposed) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }
}
