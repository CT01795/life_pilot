import 'package:life_pilot/apps/config_app.dart';

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

  factory DashboardSetting.fromJson(
    Map<String, dynamic> json,
  ) {
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
