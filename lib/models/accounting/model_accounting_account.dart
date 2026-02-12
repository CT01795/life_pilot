import 'dart:typed_data';

class ModelAccountingAccount {
  final String id;
  final String accountName;
  final Uint8List? masterGraphUrl;
  final int points;
  final int balance;
  String? currency;
  num? exchangeRate; // 與主要幣別轉換用
  final String category; // personal / project

  ModelAccountingAccount({
    required this.id,
    required this.accountName,
    required this.category,
    this.masterGraphUrl,
    this.points = 0,
    this.balance = 0,
    this.currency,
    this.exchangeRate,
  });

  ModelAccountingAccount copyWith({
    String? id,
    String? accountName,
    String? category,
    Uint8List? masterGraphUrl,
    int? points,
    int? balance,
    String? currency,
    num? exchangeRate
  }) {
    return ModelAccountingAccount(
      id: id ?? this.id,
      accountName: accountName ?? this.accountName,
      category: category ?? this.category,
      masterGraphUrl: masterGraphUrl ?? this.masterGraphUrl,
      points: points ?? this.points,
      balance: balance ?? this.balance,
      currency: currency ?? this.currency,
      exchangeRate: exchangeRate ?? this.exchangeRate,
    );
  }
}