import 'package:life_pilot/models/game/model_game_item.dart';
import 'package:life_pilot/models/game/model_game_user.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ServiceGame {
  final client = Supabase.instance.client;
  ServiceGame();

  Future<List<GameItem>> fetchGames() async {
    final data = await client
        .from('game_list')
        .select('id, game_type, game_name, level');

    // 轉成 GameItem
    return (data as List<dynamic>).map((e) {
      final map = e as Map<String, dynamic>;
      return GameItem(
        id: map['id'] as String,
        gameType: map['game_type'] as String,
        gameName: map['game_name'] as String,
        level: map['level'] as int,
      );
    }).toList();
  }

  // 查詢目前使用者的分數紀錄
  Future<List<GameUser>> fetchUserProgress(
      String userName, String gameType, String gameName) async {
    var query = client
        .from('game_user')
        .select(
            'id, name, game_id, score, created_at, game_list(game_type, game_name, level)')
        .eq('name', userName)
        .eq('game_list.game_type', gameType)
        .eq('game_list.game_name', gameName); // ✅ 指定要查的遊戲
    //.order('game_list.level', ascending: false)
    //.order('created_at', ascending: false)
    //.limit(5); // 最多 5 筆

    final data = await query;

    // 轉成 GameUser
    List<GameUser> progress =
        (data as List<dynamic>).map((e) => GameUser.fromMap(e)).toList();

    // 依 level 降序，若 level 相同則依 created_at 降序
    progress.sort((a, b) {
      final levelCompare = (b.level ?? 1).compareTo(a.level ?? 1);
      if (levelCompare != 0) return levelCompare;
      return (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0));
    });

    return progress.take(10).toList();
  }
}
