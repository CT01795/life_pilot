import 'dart:typed_data';

class ModelAccountingAccount {
  final String id;
  final String accountName;
  final Uint8List? masterGraphUrl;
  final int points;
  final int balance;

  ModelAccountingAccount({
    required this.id,
    required this.accountName,
    this.masterGraphUrl,
    this.points = 0,
    this.balance = 0,
  });

  ModelAccountingAccount copyWith({
    String? id,
    String? accountName,
    Uint8List? masterGraphUrl,
    int? points,
    int? balance,
  }) {
    return ModelAccountingAccount(
      id: id ?? this.id,
      accountName: accountName ?? this.accountName,
      masterGraphUrl: masterGraphUrl ?? this.masterGraphUrl,
      points: points ?? this.points,
      balance: balance ?? this.balance,
    );
  }
}