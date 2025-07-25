import 'package:flutter/material.dart';

class LocaleProvider extends ChangeNotifier {
  Locale _locale;

  // 建構子接受並初始化 locale
  LocaleProvider({required Locale locale}) : _locale = locale;

  // 獲取當前的 locale
  Locale get locale => _locale;

  // 切換語言的方法
  void setLocale(Locale locale) {
    _locale = locale;
    notifyListeners(); // 通知所有監聽者更新
  }
}
