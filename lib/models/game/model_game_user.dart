import 'package:life_pilot/core/const.dart';

class GameUser {
  String userName;
  int? score = 0;
  int? level = 1; // 追蹤使用者闖到哪一關
  String? gameName = constEmpty;
  String? gameType = constEmpty;
  String? gameId = constEmpty;
  GameUser(
      {required this.userName,
      this.gameId,
      this.gameType,
      this.gameName,
      this.level,
      this.score});
}
