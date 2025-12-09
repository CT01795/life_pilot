import 'dart:async';

import 'package:flutter/material.dart';
import 'package:life_pilot/controllers/auth/controller_auth.dart';
import 'package:life_pilot/core/logger.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/pages/page_type.dart';
import 'package:life_pilot/services/service_module.dart';

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
    _validateSelectedPage(); // ✅ 放到 constructor body 裡
  }

  /// async 初始化
  Future<void> init() async {
    if (!_auth.isAnonymous && _auth.currentAccount != null) {
      dbPages =
          await ServiceModule().loadModulesFromServer(_auth.currentAccount!);
      notifyListeners();
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
      ];
    }

    // ⭐ 已登入 → 基本 4 頁
    List<PageType> pages = [
      PageType.personalEvent,
      PageType.recommendedEvent,
      PageType.recommendedAttractions,
      PageType.game,
    ];

    // ⭐ optional 功能（依 DB 開放）
    const optionalMap = {
      "memoryTrace": PageType.memoryTrace,
      "accountRecords": PageType.accountRecords,
      "pointsRecord": PageType.pointsRecord,
      "ai": PageType.ai,
    };

    for (final key in dbPages) {
      if (optionalMap.containsKey(key)) {
        pages.add(optionalMap[key]!);
      }
    }
    pages.remove(PageType.game);
    // 最後加遊戲頁
    pages.add(PageType.game);

    return pages;
  }

  // ✅ 切換頁面（若不同才觸發 notify）
  void changePage(PageType newPage) {
    if (newPage == _selectedPage) return;
    _selectedPage = newPage;
    _validateSelectedPage();
    _notifyDebounced();
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
      _validateSelectedPage();
      _notifyDebounced();
    }
  }

  // ✅ 確保 selectedPage 在合法頁面範圍內
  Future<void> _validateSelectedPage() async {
    dbPages =
        await ServiceModule().loadModulesFromServer(_auth.currentAccount!);
    _notifyDebounced();
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

/*💡 優化重點說明
🔁 _notifyDebounced()	防止語系或頁面快速切換時的多次 rebuild
🧠 _validateSelectedPage()	確保使用者登出後不會停留在私人頁面
🧩 _updateIfChanged() 整合概念	實際用邏輯合併 auth / loc / locale 更新邏輯
🧱 清楚封裝 getter	外部不直接改內部狀態，強化封裝與可維護性
🧭 Log 訊息加入	方便偵錯登入狀態切換導致頁面重置的狀況*/
