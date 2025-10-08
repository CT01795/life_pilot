import 'package:flutter/material.dart';
import 'package:life_pilot/controllers/controller_auth.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/pages/page_type.dart';

class ControllerPageMain extends ChangeNotifier {
  final ControllerAuth auth;
  final void Function(List<Widget>)? onPagesChanged;
  late AppLocalizations loc;

  PageType _selectedPage;
  Locale? _lastLocale;

  PageType get selectedPage => _selectedPage;

  ControllerPageMain({
    required this.auth,
    required this.loc,
    this.onPagesChanged,
  }) : _selectedPage = auth.isAnonymous
            ? PageType.recommendedEvent
            : PageType.personalEvent;
      
  // 初始化後，從外部呼叫一次
  void init({required Locale locale}) {
    _lastLocale = locale;
  } 

  void onLocaleChanged({required AppLocalizations newLoc,
    required Locale newLocale,}) {
    loc = newLoc;
    if (newLocale != _lastLocale) {
      _lastLocale = newLocale;
    }
  }

  void changePage({required PageType newPage}) {
    if (newPage == _selectedPage) return;
    _selectedPage = newPage;
    notifyListeners();
  }
}
