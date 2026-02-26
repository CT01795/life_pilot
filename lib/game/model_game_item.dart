class ModelGameItem {
  final String id;
  final String gameType;
  final String gameName;
  final int level;

  ModelGameItem({
    required this.id,
    required this.gameType,
    required this.gameName,
    required this.level,
  });

  factory ModelGameItem.fromMap(Map<String, dynamic> map) {
    return ModelGameItem(
      id: map['id'],
      gameType: map['game_type'],
      gameName: map['game_name'],
      level: map['level'] ?? 0,
    );
  }
}
