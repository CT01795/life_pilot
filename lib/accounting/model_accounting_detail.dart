import 'package:life_pilot/utils/date_time.dart';

class ModelAccountingDetail {
  final String id;
  final String accountId;
  final DateTime createdAt;
  final DateTime date;
  final String primaryCategory;
  final String? secondaryCategory;
  final String description;
  final String type;
  final int value;
  final String currency;
  int? balance;
  num? exchangeRate;

  late final DateTime localTime;
  late final String displayTime;

  ModelAccountingDetail({
    required this.id,
    required this.accountId,
    required this.createdAt,
    required this.date,
    required this.primaryCategory,
    this.secondaryCategory,
    required this.description,
    required this.type,
    required this.value,
    required this.currency,
    this.exchangeRate,
    this.balance,
  }) {
    localTime = date.toLocal();
    displayTime = DateTimeFormatter.formatTime(localTime);
  }

  ModelAccountingDetail copyWith({
    String? description,
    int? value,
    String? currency,
    num? exchangeRate,
    int? balance,
    DateTime? date,
    String? primaryCategory,
    String? secondaryCategory,
  }) {
    return ModelAccountingDetail(
        id: id,
        accountId: accountId,
        createdAt: createdAt,
        date: date ?? this.date,
        primaryCategory: primaryCategory ?? this.primaryCategory,
        secondaryCategory: secondaryCategory ?? this.secondaryCategory,
        description: description ?? this.description,
        type: type,
        value: value ?? this.value,
        currency: currency ?? this.currency,
        exchangeRate: exchangeRate ?? this.exchangeRate,
        balance: balance ?? this.balance);
  }
}
