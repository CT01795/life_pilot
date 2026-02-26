import 'package:flutter/material.dart';

class ProviderLocale extends ChangeNotifier {
  Locale _locale;

  ProviderLocale({required Locale locale}) : _locale = locale;

  Locale get locale => _locale;

  void setLocale({required Locale locale}) {
    if (_locale == locale) return; // 避免重複通知
    _locale = locale;
    notifyListeners();
  }
}
