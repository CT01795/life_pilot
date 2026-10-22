import 'dart:typed_data';
import 'package:life_pilot/utils/value_parser.dart';

class ModelAccountingAccount {
  final String id;
  final String accountName;
  final Uint8List? masterGraphUrl;
  final num balance;
  String? currency;
  num? exchangeRate; // 與主要幣別轉換用
  final String category; // personal / project

  ModelAccountingAccount({
    required this.id,
    required this.accountName,
    required this.category,
    this.masterGraphUrl,
    this.balance = 0,
    this.currency,
    this.exchangeRate,
  });

  /// Row mapping only. Images are decoded by Service and local totals by Model.
  factory ModelAccountingAccount.fromRow(
    Map<String, dynamic> row, {
    Uint8List? masterGraphUrl,
    num? balanceOverride,
  }) => ModelAccountingAccount(
    id: row['id'],
    accountName: row['account'],
    category: row['category'],
    masterGraphUrl: masterGraphUrl,
    balance: balanceOverride ?? parseNumValue(row['balance']),
    currency: row['main_currency'],
    exchangeRate: row['exchange_rate'],
  );

  ModelAccountingAccount copyWith({
    String? id,
    String? accountName,
    String? category,
    Uint8List? masterGraphUrl,
    num? balance,
    String? currency,
    num? exchangeRate,
  }) {
    return ModelAccountingAccount(
      id: id ?? this.id,
      accountName: accountName ?? this.accountName,
      category: category ?? this.category,
      masterGraphUrl: masterGraphUrl ?? this.masterGraphUrl,
      balance: balance ?? this.balance,
      currency: currency ?? this.currency,
      exchangeRate: exchangeRate ?? this.exchangeRate,
    );
  }
}
