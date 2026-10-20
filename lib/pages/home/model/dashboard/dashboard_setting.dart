import 'package:life_pilot/apps/config_app.dart';
import 'package:life_pilot/utils/const.dart';
import 'package:life_pilot/utils/value_parser.dart';

const _notProvided = Object();

class DashboardSetting {
  final String recommendEventCity;
  final String recommendPlaceCity;
  String language;
  String? accountingAccountId;
  String? accountingAccountName;
  String? pointAccountId;
  String? pointAccountName;

  DashboardSetting({
    required this.recommendEventCity,
    required this.recommendPlaceCity,
    required this.language,
    this.accountingAccountId,
    this.accountingAccountName,
    this.pointAccountId,
    this.pointAccountName,
  });

  /// Restores missing local settings using the first valid account in each
  /// source's existing order. Does not read or write any storage.
  factory DashboardSetting.fromLocalAccounts({
    required Iterable<Map<String, dynamic>> accountingAccounts,
    required Iterable<Map<String, dynamic>> pointAccounts,
  }) {
    Map<String, dynamic>? firstValid(Iterable<Map<String, dynamic>> rows) {
      for (final row in rows) {
        if (row[Fields.isValid] == true) return row;
      }
      return null;
    }

    String? field(Map<String, dynamic>? row, String key) =>
        row?[key] == null ? null : parseStringValue(row?[key]);

    final accounting = firstValid(accountingAccounts);
    final points = firstValid(pointAccounts);
    return DashboardSetting(
      recommendEventCity: '台北',
      recommendPlaceCity: '台北',
      language: Locales.zh,
      accountingAccountId: field(accounting, Fields.id),
      accountingAccountName: field(accounting, Fields.account),
      pointAccountId: field(points, Fields.id),
      pointAccountName: field(points, Fields.account),
    );
  }

  DashboardSetting copyWith({
    String? recommendEventCity,
    String? recommendPlaceCity,
    String? language,
    Object? accountingAccountId = _notProvided,
    Object? accountingAccountName = _notProvided,
    Object? pointAccountId = _notProvided,
    Object? pointAccountName = _notProvided,
  }) {
    return DashboardSetting(
      recommendEventCity: recommendEventCity ?? this.recommendEventCity,
      recommendPlaceCity: recommendPlaceCity ?? this.recommendPlaceCity,
      language: language ?? this.language,
      accountingAccountId: identical(accountingAccountId, _notProvided)
          ? this.accountingAccountId
          : accountingAccountId as String?,
      accountingAccountName: identical(accountingAccountName, _notProvided)
          ? this.accountingAccountName
          : accountingAccountName as String?,
      pointAccountId: identical(pointAccountId, _notProvided)
          ? this.pointAccountId
          : pointAccountId as String?,
      pointAccountName: identical(pointAccountName, _notProvided)
          ? this.pointAccountName
          : pointAccountName as String?,
    );
  }

  factory DashboardSetting.fromJson(Map<String, dynamic> json) {
    return DashboardSetting(
      recommendEventCity: json['recommend_event_city'] ?? '台北',
      recommendPlaceCity: json['recommend_place_city'] ?? '台北',
      language: json['language'] ?? Locales.zh,
      accountingAccountId: json['accounting_account_id'],
      accountingAccountName: json['accounting_account_name'],
      pointAccountId: json['point_account_id'],
      pointAccountName: json['point_account_name'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'recommend_event_city': recommendEventCity,
      'recommend_place_city': recommendPlaceCity,
      'language': language,
      'accounting_account_id': accountingAccountId,
      'accounting_account_name': accountingAccountName,
      'point_account_id': pointAccountId,
      'point_account_name': pointAccountName,
    };
  }
}
