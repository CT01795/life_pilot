import 'package:flutter/material.dart';
import 'package:life_pilot/utils/safe_change_notifier.dart';

class ProviderLocale extends SafeChangeNotifier {
  Locale _locale;

  ProviderLocale({required Locale locale}) : _locale = locale;

  Locale get locale => _locale;

  void setLocale({required Locale locale}) {
    if (_locale == locale) return; // 避免重複通知
    _locale = locale;
    notifyListeners();
  }
}
