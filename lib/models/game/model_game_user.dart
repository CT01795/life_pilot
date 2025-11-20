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
  bool? isPass;
  GameUser({
    this.id,
    this.userName,
    this.gameId,
    this.score,
    this.createdAt,
    this.gameType,
    this.gameName,
    this.level,
    this.isPass
  });

  factory GameUser.fromMap(Map<String, dynamic> map) {
    return GameUser(
      id: map['id'] ?? constEmpty,
      userName: map['name'] ?? constEmpty,
      gameId: map['game_id'] ?? constEmpty,
      score: (map['score'] ?? 0).toDouble(),
      createdAt:
          map['created_at'] != null ? DateTime.parse(map['created_at']) : null,
      gameType: map['game_type'] ?? constEmpty,
      gameName: map['game_name'] ?? constEmpty,
      level: map['level'] is int
        ? map['level']
        : int.tryParse(map['level']?.toString() ?? "1") ?? 1,
      isPass: _parseBool(map['is_pass']),
    );
  }

  // 處理 PostgreSQL boolean 與字串
  static bool _parseBool(dynamic v) {
    if (v is bool) return v;
    if (v == "t") return true;
    if (v == "f") return false;
    if (v == 1) return true;
    if (v == 0) return false;
    return false;
  }
}
