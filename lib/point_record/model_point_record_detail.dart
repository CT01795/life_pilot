import 'package:life_pilot/core/date_time.dart';

class ModelPointRecordDetail {
  final String id;
  final String accountId;
  final DateTime createdAt;
  final String description;
  final String type;
  final int value;
  int? points;

  late final DateTime localTime;
  late final String displayTime;

  ModelPointRecordDetail({
    required this.id,
    required this.accountId,
    required this.createdAt,
    required this.description,
    required this.type,
    required this.value,
    this.points,
  }) {
    localTime = createdAt.toLocal();
    displayTime = DateTimeFormatter.formatTime(localTime);
  }

  ModelPointRecordDetail copyWith({
    String? description,
    int? value,
    int? points,
  }) {
    return ModelPointRecordDetail(
      id: id,
      accountId: accountId,
      createdAt: createdAt,
      description: description ?? this.description,
      type: type,
      value: value ?? this.value,
      points: points ?? this.points,
    );
  }
}
