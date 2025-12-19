class ModelPointRecord {
  final String id;
  final String accountId;
  final DateTime createdAt;
  final String description;
  final String type;
  final int value;

  ModelPointRecord({
    required this.id,
    required this.accountId,
    required this.createdAt,
    required this.description,
    required this.type,
    required this.value,
  });
}