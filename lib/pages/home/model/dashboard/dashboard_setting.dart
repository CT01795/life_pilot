import 'package:life_pilot/apps/config_app.dart';

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
    String? accountingAccountId,
    String? accountingAccountName,
    String? pointAccountId,
    String? pointAccountName,
  }) {
    return DashboardSetting(
      recommendEventCity: recommendEventCity ?? this.recommendEventCity,
      recommendPlaceCity: recommendPlaceCity ?? this.recommendPlaceCity,
      language: language ?? this.language,
      accountingAccountId: accountingAccountId ?? this.accountingAccountId,
      accountingAccountName: accountingAccountName ?? this.accountingAccountName,
      pointAccountId: pointAccountId ?? this.pointAccountId,
      pointAccountName: pointAccountName ?? this.pointAccountName,
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
