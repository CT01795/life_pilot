import 'package:life_pilot/core/date_time.dart';

class ModelPointRecord {
  final String id;
  final String accountId;
  final DateTime createdAt;
  final String description;
  final String type;
  final int value;

  late final DateTime localTime;
  late final String displayTime;

  ModelPointRecord({
    required this.id,
    required this.accountId,
    required this.createdAt,
    required this.description,
    required this.type,
    required this.value,
  }) {
    localTime = createdAt.toLocal();
    displayTime = DateTimeFormatter.formatTime(localTime);
  }

  ModelPointRecord copyWith({
    String? description,
    int? value,
  }) {
    return ModelPointRecord(
      id: id,
      accountId: accountId,
      createdAt: createdAt,
      description: description ?? this.description,
      type: type,
      value: value ?? this.value,
    );
  }
}
