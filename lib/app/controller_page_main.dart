import 'dart:async';

import 'package:flutter/material.dart';
import 'package:life_pilot/auth/controller_auth.dart';
import 'package:life_pilot/utils/const.dart';
import 'package:life_pilot/utils/enum.dart';
import 'package:life_pilot/utils/logger.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/app/service_module.dart';
import 'package:url_launcher/url_launcher.dart';

class ControllerPageMain extends ChangeNotifier {
  ControllerAuth _auth;
  AppLocalizations _loc;
  Locale _locale;
  late List<String> dbPages = [];
  PageType _selectedPage;

  Timer? _debounce;

  ControllerPageMain({
    required ControllerAuth auth,
    required AppLocalizations loc,
    required Locale initialLocale,
  })  : _auth = auth,
        _loc = loc,
        _locale = initialLocale,
        _selectedPage = auth.isAnonymous
            ? PageType.recommendedEvent
            : PageType.personalEvent {
    if (_auth.isLoggedIn) {
      loadModulesFromServer();
    }
  }

  // 📘 Getter 區
  ControllerAuth get auth => _auth;
  AppLocalizations get loc => _loc;
  Locale get locale => _locale;
  PageType get selectedPage => _selectedPage;

  // ✅ 取得目前登入狀態下可使用的頁面
  List<PageType> get availablePages {
    if (_auth.isAnonymous) {
      return const [
        PageType.recommendedEvent,
        PageType.recommendedAttractions,
        PageType.game,
        PageType.ai,
      ];
    }

    // ⭐ 已登入 → 基本 4 頁
    List<PageType> pages = [
      PageType.personalEvent,
      PageType.recommendedEvent,
      PageType.recommendedAttractions,
      PageType.game,
      PageType.ai,
    ];

    // ⭐ optional 功能（依 DB 開放）
    const optionalMap = {
      "memoryTrace": PageType.memoryTrace,
      "accountRecords": PageType.accountRecords,
      "pointsRecord": PageType.pointsRecord,
    };

    pages.remove(PageType.recommendedEvent);
    pages.remove(PageType.recommendedAttractions);
    pages.remove(PageType.game);
    pages.remove(PageType.ai);
    if (auth.currentAccount == AuthConstants.sysAdminEmail) {
      pages.add(PageType.stock);
    }
    pages.add(PageType.recommendedEvent);
    pages.add(PageType.recommendedAttractions);
    for (final key in dbPages) {
      if (optionalMap.containsKey(key)) {
        pages.add(optionalMap[key]!);
      }
    }
    // 最後加遊戲頁
    pages.add(PageType.game);
    pages.add(PageType.ai);
    if (auth.currentAccount == AuthConstants.sysAdminEmail) {
      pages.add(PageType.feedbackAdmin);
      pages.add(PageType.businessPlan);
    }

    return pages;
  }

  // ✅ 切換頁面（若不同才觸發 notify）
  void changePage(PageType newPage) {
    // ⭐ AI → 直接開外部瀏覽器，不切頁
    if (newPage == PageType.ai) {
      _openAI();
      return;
    }
    if (newPage == _selectedPage) return;
    _selectedPage = newPage;
    _validateSelectedPage();
    _notifyDebounced();
  }

  Future<void> _openAI() async {
    final uri = Uri.parse('https://chatgpt.com/zh-TW');

    if (!await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    )) {
      logger.e('❌ Can\'t open ChatGPT');
    }
  }

  // ✅ 更新語系與登入資訊
  void updateLocalization(
      AppLocalizations loc, Locale locale, ControllerAuth? auth) {
    bool changed = false;

    if (auth != null && auth != _auth) {
      _auth = auth;
      changed = true;
    }
    if (_loc != loc) {
      _loc = loc;
      changed = true;
    }
    if (_locale != locale) {
      _locale = locale;
      changed = true;
    }
    if (changed) {
      if (_auth.isLoggedIn) {
        loadModulesFromServer();
      }
      _notifyDebounced();
    }
  }

  // ✅ 確保 selectedPage 在合法頁面範圍內
  Future<void> loadModulesFromServer() async {
    dbPages =
        await ServiceModule().loadModulesFromServer(_auth.currentAccount!);
    _validateSelectedPage();
    notifyListeners();
  }

  // ✅ 確保 selectedPage 在合法頁面範圍內
  void _validateSelectedPage() {
    if (!availablePages.contains(_selectedPage)) {
      logger.i('🔄 Page $_selectedPage 無效，重設為 ${availablePages.first}（登入狀態改變）');
      _selectedPage = availablePages.first;
    }
  }

  // ✅ Debounce 通知，避免頻繁 rebuild
  void _notifyDebounced() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 120), () {
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }
}
