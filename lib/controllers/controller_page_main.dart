import 'package:flutter/material.dart';
import 'package:life_pilot/controllers/controller_auth.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/pages/page_type.dart';
import 'package:life_pilot/utils/core/utils_const.dart';
import 'package:life_pilot/providers/provider.dart'; // 引入 appBarWidgetsProvider

class ControllerPageMain extends ChangeNotifier {
  final ControllerAuth auth;
  late AppLocalizations loc;

  PageType _selectedPage;
  Locale? _lastLocale;

  PageType get selectedPage => _selectedPage;

  ControllerPageMain({
    required this.auth,
    required this.loc,
  }) : _selectedPage = auth.isAnonymous
            ? PageType.recommendedEvent
            : PageType.personalEvent;

  // 初始化後，從外部呼叫一次
  void init({required Locale locale}) {
    _lastLocale = locale;
    _notifyAppBar(); // 初始化時也要建 dropdown
  }

  void onLocaleChanged({
    required AppLocalizations newLoc,
    required Locale newLocale,
  }) {
    loc = newLoc;
    if (newLocale != _lastLocale) {
      _lastLocale = newLocale;
      _notifyAppBar(); // 語言改變也要重新 build dropdown
    }
  }

  void changePage({required PageType newPage}) {
    if (newPage == _selectedPage) return;
    _selectedPage = newPage;
    notifyListeners();
    _notifyAppBar(); // ⬅️ 切頁後主動刷新 AppBar Dropdown
  }

  void _notifyAppBar() {
    final options = auth.isAnonymous
        ? [PageType.recommendedEvent, PageType.recommendedAttractions]
        : PageType.values;

    final dropdown = DropdownButtonHideUnderline(
      child: DropdownButton<PageType>(
        value: _selectedPage,
        style: const TextStyle(color: Colors.white),
        dropdownColor: const Color(0xFF0066CC),
        iconEnabledColor: Colors.white,
        items: options
            .map((page) => DropdownMenuItem(
                  value: page,
                  child: Text(page.title(loc: loc)),
                ))
            .toList(),
        onChanged: (value) {
          if (value != null) changePage(newPage: value);
        },
      ),
    );

    // 延遲更新，避免 build 期間修改 notifier
    WidgetsBinding.instance.addPostFrameCallback((_) {
      appBarWidgetsProvider.value = [dropdown, kGapW8()];
    });
  }
}
