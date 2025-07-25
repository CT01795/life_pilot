import 'dart:ui';

import 'package:life_pilot/providers/locale_provider.dart';

void toggleLocale(LocaleProvider localeProvider) {
  /*final current = localeProvider.locale;
  final newLocale = current.languageCode == 'en' ? Locale('zh') : Locale('en');
  localeProvider.setLocale(newLocale);*/

  final supportedLocales = [Locale('en'), Locale('zh')];
  final currentIndex = supportedLocales.indexWhere((l) => l.languageCode == localeProvider.locale.languageCode);
  final nextIndex = (currentIndex + 1) % supportedLocales.length;
  localeProvider.setLocale(supportedLocales[nextIndex]);
}