import 'package:life_pilot/core/const.dart';

class GameUser {
  String? id = constEmpty;
  String? userName;
  String? gameId = constEmpty;
  double? score = 0;
  DateTime? createdAt;
  String? gameType = constEmpty;
  String? gameName = constEmpty;
  int? level; // 追蹤使用者闖到哪一關
  GameUser(
      {this.id,
      this.userName,
      this.gameId,
      this.score,
      this.createdAt,
      this.gameType,
      this.gameName,
      this.level,});

  factory GameUser.fromMap(Map<String, dynamic> map) {
    return GameUser(
      id: map['id'] ?? constEmpty,
      userName: map['name'] ?? constEmpty,
      gameId: map['game_id'] ?? constEmpty,
      score: (map['score'] ?? 0).toDouble(),
      createdAt: map['created_at'] != null ? DateTime.parse(map['created_at']) : null,
      gameType: map['game_type'] ?? constEmpty,
      gameName: map['game_name'] ?? constEmpty,
      level: map['level']?.toInt() ?? 1,
    );
  }
}
