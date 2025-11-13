import 'package:flutter/material.dart';
import 'package:life_pilot/models/game/model_game_item.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ControllerGameList extends ChangeNotifier {
  List<GameItem> gameList = [];
  List<String> gameCategories = [];
  Map<String, List<GameItem>> gamesByCategory = {};
  final client = Supabase.instance.client;

  Future<void> loadGames() async {
    final data = await client
        .from('game_list')
        .select('id, game_type, game_name, level');

    // 轉成 GameItem
    gameList =
        (data as List<dynamic>).map((e) {
      final map = e as Map<String, dynamic>;
      return GameItem(
        id: map['id'] as String,
        gameType: map['game_type'] as String,
        gameName: '${map['game_name']} ${map['level']}',
        level: map['level'] as int,
      );
    }).toList();

    // 分類
    gamesByCategory.clear();
    for (var g in gameList) {
      gamesByCategory.putIfAbsent(g.gameType, () => []).add(g);
    }
    gameCategories = gamesByCategory.keys.toList();

    notifyListeners();
  }
}
