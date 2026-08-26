import 'package:life_pilot/utils/date_time.dart';

class ModelPointRecordDetail {
  final String id;
  final String accountId;
  final DateTime createdAt;
  final DateTime date;
  final String primaryCategory;
  final String? secondaryCategory;
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
    required this.date,
    required this.primaryCategory,
    this.secondaryCategory,
    required this.description,
    required this.type,
    required this.value,
    this.points,
  }) {
    localTime = date.toLocal();
    displayTime = DateTimeFormatter.formatTime(localTime);
  }

  ModelPointRecordDetail copyWith({
    String? description,
    int? value,
    int? points,
    DateTime? date,
    String? primaryCategory,
    String? secondaryCategory,
  }) {
    return ModelPointRecordDetail(
      id: id,
      accountId: accountId,
      createdAt: createdAt,
      date: date ?? this.date,
      primaryCategory: primaryCategory ?? this.primaryCategory,
      secondaryCategory: secondaryCategory ?? this.secondaryCategory,
      description: description ?? this.description,
      type: type,
      value: value ?? this.value,
      points: points ?? this.points,
    );
  }
}
