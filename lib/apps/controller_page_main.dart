import 'dart:async';

import 'package:flutter/material.dart';
import 'package:life_pilot/apps/service_module.dart';
import 'package:life_pilot/auth/controller_auth.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/utils/enum.dart';
import 'package:life_pilot/utils/logger.dart';
import 'package:life_pilot/utils/safe_change_notifier.dart';
import 'package:url_launcher/url_launcher.dart';

class ControllerPageMain extends SafeChangeNotifier {
  ControllerPageMain({
    required ControllerAuth auth,
    required AppLocalizations loc,
    required Locale initialLocale,
    ServiceModule? serviceModule,
  }) : _auth = auth,
       _loc = loc,
       _locale = initialLocale,
       _serviceModule = serviceModule ?? ServiceModule(),
       _accountKey = auth.currentAccount?.trim().toLowerCase(),
       _wasAdmin = auth.isSysAdmin,
       _wasVendor = auth.isVendor,
       _selectedPage = auth.isVendor
           ? PageType.vendorDashboard
           : PageType.home {
    unawaited(_reloadModules());
  }

  static const basePages = <PageType>[
    PageType.home,
    PageType.personalEvent,
    PageType.recommendEvent,
    PageType.recommendPlaces,
    PageType.memoryTrace,
    PageType.accountRecords,
  ];

  static const vendorPages = <PageType>[
    PageType.vendorDashboard,
    PageType.recommendEvent,
    PageType.recommendPlaces,
  ];

  static const grantablePageKeys = <PageType, String>{
    PageType.pointsRecord: 'pointsRecord',
    PageType.game: 'game',
    PageType.ai: 'ai',
    PageType.stock: 'stock',
    PageType.businessPlan: 'businessPlan',
    PageType.feedbackAdmin: 'feedbackAdmin',
  };

  ControllerAuth _auth;
  AppLocalizations _loc;
  Locale _locale;
  final ServiceModule _serviceModule;
  String? _accountKey;
  bool _wasAdmin;
  bool _wasVendor;
  Set<String> _moduleKeys = const {};
  bool _modulesLoading = false;
  int _moduleRequest = 0;
  PageType _selectedPage;
  Timer? _debounce;

  ControllerAuth get auth => _auth;
  AppLocalizations get loc => _loc;
  Locale get locale => _locale;
  PageType get selectedPage => _selectedPage;
  bool get modulesLoading => _modulesLoading;
  Set<String> get moduleKeys => Set.unmodifiable(_moduleKeys);

  List<PageType> get availablePages {
    if (auth.isVendor) return vendorPages;
    final pages = <PageType>[...basePages];
    for (final entry in grantablePageKeys.entries) {
      if (auth.isSysAdmin || _moduleKeys.contains(entry.value)) {
        pages.add(entry.key);
      }
    }
    return pages;
  }

  bool canAccess(PageType page) => availablePages.contains(page);

  void changePage(PageType newPage) {
    if (!canAccess(newPage)) return;
    if (newPage == PageType.ai) {
      unawaited(_openAI());
      return;
    }
    if (newPage == _selectedPage) return;
    _selectedPage = newPage;
    _notifyDebounced();
  }

  Future<void> refreshModules() => _reloadModules(force: true);

  Future<void> _reloadModules({bool force = false}) async {
    final account = _accountKey;
    final request = ++_moduleRequest;
    if (account == null || account.isEmpty || auth.isSysAdmin) {
      _moduleKeys = const {};
      _modulesLoading = false;
      _validateSelectedPage();
      _notifyDebounced();
      return;
    }
    _modulesLoading = true;
    if (force) _notifyDebounced();
    final keys = await _serviceModule.loadModulesFromServer(account);
    if (request != _moduleRequest || account != _accountKey) return;
    _moduleKeys = keys.toSet();
    _modulesLoading = false;
    _validateSelectedPage();
    _notifyDebounced();
  }

  Future<void> _openAI() async {
    final uri = Uri.parse('https://chatgpt.com/zh-TW');
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      logger.e('Can\'t open ChatGPT');
    }
  }

  void updateLocalization(
    AppLocalizations loc,
    Locale locale,
    ControllerAuth? auth,
  ) {
    var changed = false;
    var sessionChanged = false;
    if (auth != null) {
      final nextAccount = auth.currentAccount?.trim().toLowerCase();
      final nextIsAdmin = auth.isSysAdmin;
      final nextIsVendor = auth.isVendor;
      sessionChanged =
          nextAccount != _accountKey ||
          nextIsAdmin != _wasAdmin ||
          nextIsVendor != _wasVendor;
      _auth = auth;
      if (sessionChanged) {
        _accountKey = nextAccount;
        _wasAdmin = nextIsAdmin;
        _wasVendor = nextIsVendor;
        _moduleKeys = const {};
        _selectedPage = nextIsVendor ? PageType.vendorDashboard : PageType.home;
        changed = true;
      }
    }
    if (_loc != loc) {
      _loc = loc;
      changed = true;
    }
    if (_locale != locale) {
      _locale = locale;
      changed = true;
    }
    if (sessionChanged) unawaited(_reloadModules());
    if (changed) _notifyDebounced();
  }

  void _validateSelectedPage() {
    if (!availablePages.contains(_selectedPage)) {
      _selectedPage = PageType.home;
      if (auth.isVendor) _selectedPage = PageType.vendorDashboard;
    }
  }

  void _notifyDebounced() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 80), notifyListeners);
  }

  @override
  void dispose() {
    _moduleRequest++;
    _debounce?.cancel();
    super.dispose();
  }
}
