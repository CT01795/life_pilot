import 'package:life_pilot/models/game/model_game_item.dart';
import 'package:life_pilot/models/game/model_game_user.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ServiceGame {
  final client = Supabase.instance.client;
  ServiceGame();

  Future<List<ModelGameItem>> fetchGames() async {
    final data = await client
        .from('game_list')
        .select('id, game_type, game_name, level');

    // 轉成 GameItem
    return (data as List<dynamic>).map((e) {
      final map = e as Map<String, dynamic>;
      return ModelGameItem(
        id: map['id'] as String,
        gameType: map['game_type'] as String,
        gameName: map['game_name'] as String,
        level: int.tryParse(map['level']?.toString() ?? '') ?? 1,
      );
    }).toList();
  }

  // 查詢目前使用者的分數紀錄
  Future<List<ModelGameUser>> fetchUserProgress(
      String userName, String gameType, String gameName) async {
    final response = await client.rpc('fetch_user_progress', params: {
      'p_name': userName,
      'p_game_type': gameType,
      'p_game_name': gameName,
    });

    final data = response as List<dynamic>;
    return data.map((e) => ModelGameUser.fromMap(e)).toList();
  }

  Future<void> saveUserGameScore(
      {required String newUserName,
      required double newScore,
      required String? newGameId,
      bool? newIsPass}) async {
    if (newScore == 0) {
      return;
    }
    await client.from('game_user').insert({
      'game_id': newGameId,
      'score': newScore,
      'name': newUserName,
      'is_pass': newIsPass,
      'created_at': DateTime.now().toIso8601String(), // 強制存 UTC
    });
  }
}
