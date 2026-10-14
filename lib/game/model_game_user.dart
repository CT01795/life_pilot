import 'package:life_pilot/utils/const.dart';
import 'package:life_pilot/utils/value_parser.dart';

class ModelGameUser {
  String? id = '';
  String? userName;
  String? gameId = '';
  num? score = 0;
  DateTime? createdAt;
  String? gameType = '';
  String? gameName = '';
  int? level; // 追蹤使用者闖到哪一關
  bool? isPass;
  ModelGameUser({
    this.id,
    this.userName,
    this.gameId,
    this.score,
    this.createdAt,
    this.gameType,
    this.gameName,
    this.level,
    this.isPass,
  });

  factory ModelGameUser.fromMap(Map<String, dynamic> map) {
    return ModelGameUser(
      id: map[Fields.id] ?? '',
      userName: map['name'] ?? '',
      gameId: map['game_id'] ?? '',
      score: parseDoubleValue(map['score']),
      createdAt: tryParseDateTimeValue(map[Fields.createdAt], toLocal: true),
      gameType: map['game_type'] ?? '',
      gameName: map['game_name'] ?? '',
      level: parseIntValue(map['level'], fallback: 1),
      isPass: parseBoolValue(map['is_pass']),
    );
  }
}
