import 'package:flutter/material.dart';
import 'package:life_pilot/calendar/controller_calendar.dart';
import 'package:life_pilot/pages/home/model/dashboard/model_dashboard.dart';
import 'package:life_pilot/utils/api.dart';
import 'package:life_pilot/utils/enum.dart';
import 'package:life_pilot/utils/logger.dart';
import 'package:life_pilot/utils/safe_change_notifier.dart';
import 'package:life_pilot/auth/service_auth.dart';
import 'package:life_pilot/auth/auth_session_sync.dart';
import 'package:life_pilot/utils/const.dart';
import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:life_pilot/subscription/model_subscription_usage.dart';
import 'package:life_pilot/subscription/service_subscription.dart';
import 'package:life_pilot/local_storage/local_data_store.dart';

class ControllerAuth extends SafeChangeNotifier {
  final ControllerCalendar? controllerCalendar;
  final ModelDashboard? modelDashboard;
  StreamSubscription<AuthState>? _authSubscription;
  StreamSubscription<void>? _externalSignedOutSubscription;
  StreamSubscription<void>? _passwordRecoveryLinkSubscription;
  ControllerAuth({this.controllerCalendar, this.modelDashboard});

  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }
    _initialized = true;
    _listenAuthState();
    _listenExternalSignedOut();
    _passwordRecoveryLinkSubscription =
        ServiceAuth.passwordRecoveryLinks.listen((_) {
      ServiceAuth.consumePasswordRecoveryLink();
      _update(() => _currentPage = AuthPage.resetPassword);
    });
    if (ServiceAuth.consumePasswordRecoveryLink()) {
      _currentPage = AuthPage.resetPassword;
    }
  }

  void _listenAuthState() {
    _authSubscription = supabase.auth.onAuthStateChange.listen((data) {
      logger.i('Auth Event: ${data.event}');
      logger.i(
        'Recovery User Present: ${data.session?.user != null}',
      );
      logger.i(
        'Current User Present: ${supabase.auth.currentUser != null}',
      );
      if (data.event == AuthChangeEvent.passwordRecovery) {
        _update(() {
          _currentPage = AuthPage.resetPassword;
        });
      } else if (data.event == AuthChangeEvent.signedOut) {
        _handleSignedOut();
      }
    });
  }

  void _listenExternalSignedOut() {
    _externalSignedOutSubscription = externalSignedOutEvents.listen((_) {
      if (_isLoggedIn) {
        logger.i('Session was signed out from another browser tab.');
        _handleSignedOut();
      }
    });
  }

  // -------------------- 狀態 --------------------
  bool _isLoading = true;
  bool _isLoggedIn = false;
  bool _isAnonymous = false;
  String? _currentAccount;
  SubscriptionSnapshot _subscription = SubscriptionSnapshot.free;
  DataStorageLocation _preferredStorage = DataStorageLocation.cloud;
  bool _hasStorageChoice = false;
  AuthPage _currentPage = AuthPage.login;

  bool get isLoading => _isLoading;
  bool get isLoggedIn => _isLoggedIn;
  bool get isAnonymous => _isAnonymous;
  String? get currentAccount => _currentAccount;
  SubscriptionSnapshot get subscription => _subscription;
  bool get isPlus => isSysAdmin || _subscription.isPlus;
  DataStorageLocation get preferredStorage => _preferredStorage;
  bool get storesNewDataLocally =>
      _preferredStorage == DataStorageLocation.local;
  bool get hasStorageChoice => _hasStorageChoice;
  bool get hasServerAdminRole =>
      supabase.auth.currentUser?.appMetadata['role'] == AuthConstants.adminRole;
  bool get isSysAdmin => hasServerAdminRole;
  AuthPage get currentPage => _currentPage;

  Future<void> refreshSubscriptionUsage({bool notify = true}) async {
    if (!_isLoggedIn || _isAnonymous) return;
    try {
      _subscription = _preferredStorage == DataStorageLocation.local &&
              _subscription.usage.isNotEmpty
          ? await _withLocalUsage(_subscription)
          : await _loadSubscriptionUsage();
      if (notify) notifyListeners();
    } catch (error, stackTrace) {
      logger.e('Failed to refresh subscription usage',
          error: error, stackTrace: stackTrace);
    }
  }

  Future<SubscriptionSnapshot> _loadSubscriptionUsage() async {
    final cloud = await ServiceSubscription().fetchMyUsage();
    final account = _currentAccount;
    if (_preferredStorage != DataStorageLocation.local || account == null) {
      return cloud;
    }

    return _withLocalUsage(cloud);
  }

  Future<SubscriptionSnapshot> _withLocalUsage(
    SubscriptionSnapshot base,
  ) async {
    final account = _currentAccount;
    if (account == null) return base;

    final resources = [
      TableNames.calendarEvents,
      TableNames.accountingDetail,
      TableNames.pointRecordDetail,
      TableNames.memoryTrace,
      'game_grammar',
      'game_sentence',
      'game_translation',
      TableNames.gameSocialScenarios,
    ];
    final counts = await LocalDataStore.instance.countByResources(
      owner: account,
      resources: resources,
    );
    int count(String resource) => counts[resource] ?? 0;
    final localUsage = Map<String, SubscriptionUsage>.from(base.usage)
      ..['calendar_events'] = SubscriptionUsage(
        resource: 'calendar_events',
        used: count(TableNames.calendarEvents),
        quota: -1,
      )
      ..['accounting_detail'] = SubscriptionUsage(
        resource: 'accounting_detail',
        used: count(TableNames.accountingDetail),
        quota: -1,
      )
      ..['point_record_detail'] = SubscriptionUsage(
        resource: 'point_record_detail',
        used: count(TableNames.pointRecordDetail),
        quota: -1,
      )
      ..['memory_trace'] = SubscriptionUsage(
        resource: 'memory_trace',
        used: count(TableNames.memoryTrace),
        quota: -1,
      )
      ..['game_questions'] = SubscriptionUsage(
        resource: 'game_questions',
        used: count('game_grammar') +
            count('game_sentence') +
            count('game_translation') +
            count(TableNames.gameSocialScenarios),
        quota: -1,
      );
    return base.copyWithUsage(localUsage);
  }

  Future<void> setPreferredStorage(DataStorageLocation location) async {
    final account = _currentAccount;
    if (account == null || _isAnonymous) return;
    await LocalDataStore.instance.setPreferredLocation(account, location);
    _preferredStorage = location;
    _hasStorageChoice = true;
    notifyListeners();
    await refreshSubscriptionUsage();
    modelDashboard?.switchAccount(account);
    controllerCalendar?.clearAll();
    try {
      await Future.wait<void>([
        if (modelDashboard != null) ...[
          modelDashboard!.loadEventCities(account),
          modelDashboard!.loadPlaceCities(account),
          modelDashboard!.refreshAll(account: account),
        ],
        if (controllerCalendar != null)
          controllerCalendar!.loadCalendarEvents(month: DateTime.now()),
      ]);
    } catch (error, stackTrace) {
      logger.e(
        'Failed to refresh data after changing storage location',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  final Map<String, String> _registerMap = {
    AuthConstants.email: '',
  };

  Map<String, String> get registerMap => Map.unmodifiable(_registerMap);

  // =========================================================
  // 🔹 統一狀態更新入口
  void _update(VoidCallback fn, {bool notify = true}) {
    fn();
    if (notify) notifyListeners();
  }

  void _handleSignedOut() {
    if (_currentAccount != null && !_isAnonymous) {
      _registerMap[AuthConstants.email] = _currentAccount!;
    }

    _update(() {
      _isLoading = false;
      _isLoggedIn = false;
      _isAnonymous = false;
      _currentAccount = null;
      _subscription = SubscriptionSnapshot.free;
      _preferredStorage = DataStorageLocation.cloud;
      _hasStorageChoice = false;
      _currentPage = AuthPage.login;
    }, notify: false);

    modelDashboard?.switchAccount(null);
    controllerCalendar?.clearAll();
    notifyListeners();
  }

  // =========================================================
  // 🧩 檢查登入狀態
  Future<void> checkLoginStatus() async {
    _update(() => _isLoading = true, notify: false);

    final user = supabase.auth.currentUser;
    final oldAccount = _currentAccount; // 👈 比對用

    // 有時在剛登入／註冊完畢會延遲更新；
    await Future.delayed(const Duration(milliseconds: 250));

    _update(() {
      _isLoggedIn = user != null;
      _isAnonymous = user?.isAnonymous ?? false;
      _currentAccount = _isAnonymous ? AuthConstants.guest : user?.email;
      if (_currentPage != AuthPage.resetPassword) {
        _currentPage = _isLoggedIn ? AuthPage.pageMain : AuthPage.login;
      }
    }, notify: false);

    if (_isLoggedIn && !_isAnonymous) {
      final storedLocation =
          await LocalDataStore.instance.preferredLocation(_currentAccount!);
      _hasStorageChoice = storedLocation != null;
      _preferredStorage = storedLocation ?? DataStorageLocation.cloud;
    }

    // 🧹 若帳號不同，清空並重新載入日曆資料
    if (!_isLoggedIn) {
      controllerCalendar?.clearAll();
      modelDashboard?.switchAccount(null);
    } else if (_currentAccount != oldAccount) {
      controllerCalendar?.clearAll();
      modelDashboard?.switchAccount(_currentAccount);
      await controllerCalendar?.loadCalendarEvents(month: DateTime.now());
    }

    if (_isLoggedIn && !_isAnonymous) {
      try {
        _subscription = await _loadSubscriptionUsage();
      } catch (error, stackTrace) {
        logger.e('Failed to load subscription usage',
            error: error, stackTrace: stackTrace);
        _subscription = SubscriptionSnapshot.free;
      }
    }

    _update(() => _isLoading = false);
  }

  // =========================================================
  // 🔐 通用登入邏輯（登入/匿名登入/註冊共用）
  Future<String?> _authenticate(Future<String?> Function() action) async {
    _update(() => _isLoading = true, notify: false);
    try {
      final error = await action();
      if (error != null) return error;
      await checkLoginStatus();
      return null;
    } catch (e, st) {
      logger.e('Auth Error: $e\n$st');
      return ErrorFields.loginError;
    } finally {
      _update(() => _isLoading = false, notify: false);
    }
  }

  // -------------------- 登入 --------------------
  Future<String?> login({required String email, required String password}) =>
      _authenticate(() => ServiceAuth.login(email: email, password: password));

  // -------------------- 註冊 --------------------
  Future<String?> register({required String email, required String password}) =>
      _authenticate(
          () => ServiceAuth.register(email: email, password: password));

  // -------------------- 登出 --------------------
  Future<String?> logout() async {
    _update(() => _isLoading = true, notify: false);

    final error = await ServiceAuth.logout();
    if (error != null) {
      _update(() => _isLoading = false);
      return error;
    }

    if (_currentAccount != null && !_isAnonymous) {
      _registerMap[AuthConstants.email] = _currentAccount!;
    }

    _update(() {
      _isLoggedIn = false;
      _isAnonymous = false;
      _currentAccount = null;
      _subscription = SubscriptionSnapshot.free;
      _preferredStorage = DataStorageLocation.cloud;
      _hasStorageChoice = false;
      _currentPage = AuthPage.login;
    }, notify: false);

    modelDashboard?.switchAccount(null);
    controllerCalendar?.clearAll(); // 🧹 登出也清除資料

    _update(() => _isLoading = false);
    return null;
  }

  // -------------------- 忘記密碼 --------------------
  Future<String?> resetPassword({required String email}) =>
      ServiceAuth.resetPassword(email: email);

  // -------------------- 頁面切換 --------------------
  void goToPage(AuthPage page, {String? email}) {
    _update(() {
      if (email != null) _registerMap[AuthConstants.email] = email;
      _currentPage = page;
    });
  }

  void goToRegister({String? email}) =>
      goToPage(AuthPage.register, email: email);
  void goToResetPassword({String? email}) =>
      goToPage(AuthPage.resetPassword, email: email);
  void goBackToLogin({String? email}) => goToPage(AuthPage.login, email: email);

  @override
  void dispose() {
    _authSubscription?.cancel();
    _externalSignedOutSubscription?.cancel();
    _passwordRecoveryLinkSubscription?.cancel();
    super.dispose();
  }
}
