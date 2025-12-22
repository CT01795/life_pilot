import 'dart:typed_data';

class ModelPointRecordAccount {
  final String id;
  final String accountName;
  Uint8List? masterGraphUrl;
  int points;
  int balance;

  ModelPointRecordAccount({
    required this.id,
    required this.accountName,
    this.masterGraphUrl,
    this.points = 0,
    this.balance = 0,
  });

  ModelPointRecordAccount copyWith({
    String? id,
    String? accountName,
    Uint8List? masterGraphUrl,
    int? points,
    int? balance,
  }) {
    return ModelPointRecordAccount(
      id: id ?? this.id,
      accountName: accountName ?? this.accountName,
      masterGraphUrl: masterGraphUrl ?? this.masterGraphUrl,
      points: points ?? this.points,
      balance: balance ?? this.balance,
    );
  }
}