import 'package:flutter/material.dart';

class ProviderLocale extends ChangeNotifier {
  Locale _locale;

  ProviderLocale({required Locale locale}) : _locale = locale;

  Locale get locale => _locale;

  void setLocale(Locale locale) {
    _locale = locale;
    notifyListeners();
  }
}
