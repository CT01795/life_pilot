class GameItem {
  final String id;
  final String gameType;
  final String gameName;
  final int level;

  GameItem({
    required this.id,
    required this.gameType,
    required this.gameName,
    required this.level,
  });

  factory GameItem.fromMap(Map<String, dynamic> map) {
    return GameItem(
      id: map['id'],
      gameType: map['game_type'],
      gameName: map['game_name'],
      level: map['level'] ?? 0,
    );
  }
}
