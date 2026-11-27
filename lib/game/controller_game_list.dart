import 'package:life_pilot/game/model_game_catalog.dart';
import 'package:life_pilot/game/model_game_item.dart';
import 'package:life_pilot/game/service_game.dart';
import 'package:life_pilot/utils/refresh_request_coordinator.dart';
import 'package:life_pilot/utils/safe_change_notifier.dart';

/// Loads the catalog; play history belongs to ControllerGameProgress.
class ControllerGameList extends SafeChangeNotifier {
  ControllerGameList({required this.serviceGame});

  final ServiceGame serviceGame;
  ModelGameCatalog _catalog = ModelGameCatalog(const []);
  final _loads = RefreshRequestCoordinator();
  int _revision = 0;
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

  /// Ordinary callers share the active read; a write queues a fresh read.
  Future<void> loadGames({bool force = false}) {
    if (notifierDisposed) return Future.value();
    if (force && _loads.isRunning) _revision++;
    return _loads.run(() => _loadGames(force: force), force: force);
  }

  Future<void> _loadGames({required bool force}) async {
    if (notifierDisposed) return;
    final revision = ++_revision;
    bool current() => !notifierDisposed && revision == _revision;
    _isLoading = true;
    _loadError = null;
    notifyListeners();
    try {
      // A listener may close the page before the service read starts.
      if (!current()) return;
      final games = await serviceGame.fetchGames(force: force);
      if (!current()) return;
      _catalog = ModelGameCatalog(games);
    } catch (error) {
      if (current()) {
        _loadError = error;
        rethrow;
      }
    } finally {
      if (current()) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }
}
