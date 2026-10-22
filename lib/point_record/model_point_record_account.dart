import 'dart:typed_data';
import 'package:life_pilot/utils/value_parser.dart';

class ModelPointRecordAccount {
  final String id;
  final String accountName;
  final Uint8List? masterGraphUrl;
  final int points;
  final String category; // personal / project

  ModelPointRecordAccount({
    required this.id,
    required this.accountName,
    required this.category,
    this.masterGraphUrl,
    this.points = 0,
  });

  /// Row mapping only; never decode image payloads or recalculate local totals.
  factory ModelPointRecordAccount.fromRow(
    Map<String, dynamic> row, {
    Uint8List? masterGraphUrl,
    int? pointsOverride,
  }) => ModelPointRecordAccount(
    id: row['id'],
    accountName: row['account'],
    category: row['category'],
    masterGraphUrl: masterGraphUrl,
    points: pointsOverride ?? parseIntValue(row['points']),
  );

  ModelPointRecordAccount copyWith({
    String? id,
    String? accountName,
    String? category,
    Uint8List? masterGraphUrl,
    int? points,
  }) {
    return ModelPointRecordAccount(
      id: id ?? this.id,
      accountName: accountName ?? this.accountName,
      category: category ?? this.category,
      masterGraphUrl: masterGraphUrl ?? this.masterGraphUrl,
      points: points ?? this.points,
    );
  }
}
