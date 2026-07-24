import 'package:flutter/material.dart';

class ModelDashboardSetting extends ChangeNotifier {
  //==========================
  // 推薦地區
  //==========================

  String _city = '台北';

  String get city => _city;

  void changeCity(String value) {
    if (_city == value) return;

    _city = value;
    notifyListeners();
  }

  //==========================
  // 記帳首頁使用的帳戶
  //==========================

  String? _accountId;

  String? get accountId => _accountId;

  void changeAccount(String? value) {
    if (_accountId == value) return;

    _accountId = value;
    notifyListeners();
  }

  //==========================
  // 點數首頁使用的帳戶
  //==========================

  String? _pointAccountId;

  String? get pointAccountId => _pointAccountId;

  void changePointAccount(String? value) {
    if (_pointAccountId == value) return;

    _pointAccountId = value;
    notifyListeners();
  }
}