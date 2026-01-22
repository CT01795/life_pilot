import 'package:intl/intl.dart';

class ModelAccounting {
  final String id;
  final String accountId;
  final DateTime createdAt;
  final String description;
  final String type;
  final int value;
  final String currency; 
  num? exchangeRate; 

  late final DateTime localTime;
  late final String displayTime;

  ModelAccounting({
    required this.id,
    required this.accountId,
    required this.createdAt,
    required this.description,
    required this.type,
    required this.value,
    required this.currency,
    this.exchangeRate
  }) {
    localTime = createdAt.toLocal();
    displayTime = _formatTime(localTime);
  }

  ModelAccounting copyWith({
    String? description,
    int? value,
    String? currency,
    num? exchangeRate,
  }) {
    return ModelAccounting(
      id: id,
      accountId: accountId,
      createdAt: createdAt,
      description: description ?? this.description,
      type: type,
      value: value ?? this.value,
      currency: currency ?? this.currency,
      exchangeRate: exchangeRate ?? this.exchangeRate,
    );
  }

  static String _formatTime(DateTime time) {
    final now = DateTime.now();
    return time.year == now.year
        ? time.month == now.month && time.day == now.day
            ? DateFormat('HH:mm').format(time)
            : DateFormat('M/d HH:mm').format(time)
        : DateFormat('yyyy/M/d HH:mm').format(time);
  }
}
