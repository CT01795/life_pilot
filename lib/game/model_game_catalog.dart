import 'package:life_pilot/game/model_game_item.dart';

/// Immutable menu snapshot. Preserve the ordering supplied by ServiceGame.
class ModelGameCatalog {
  ModelGameCatalog(Iterable<ModelGameItem> games) {
    final grouped = <String, Map<String, List<ModelGameItem>>>{};
    final index = <(String, String, int), ModelGameItem>{};
    ModelGameItem? first;
    for (final game in games) {
      first ??= game;
      grouped
          .putIfAbsent(game.gameType, () => {})
          .putIfAbsent(game.gameName, () => [])
          .add(game);
      // Match the old firstWhere behavior if duplicate levels exist.
      index.putIfAbsent((game.gameType, game.gameName, game.level), () => game);
    }
    firstGame = first;
    gamesByCategory = Map.unmodifiable({
      for (final category in grouped.entries)
        category.key: Map<String, List<ModelGameItem>>.unmodifiable({
          for (final game in category.value.entries)
            game.key: List<ModelGameItem>.unmodifiable(game.value),
        }),
    });
    categories = List.unmodifiable(grouped.keys);
    _byLevel = Map.unmodifiable(index);
  }

  late final Map<String, Map<String, List<ModelGameItem>>> gamesByCategory;
  late final List<String> categories;
  late final ModelGameItem? firstGame;
  late final Map<(String, String, int), ModelGameItem> _byLevel;

  ModelGameItem? findGame({String? gameType, String? gameName, int? level}) {
    if (gameType == null || gameName == null || level == null) return null;
    final match = _byLevel[(gameType, gameName, level)];
    if (match != null) return match;
    final levels = gamesByCategory[gameType]?[gameName];
    return levels == null || levels.isEmpty ? null : levels.first;
  }
}
