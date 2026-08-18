import 'package:flutter/material.dart';
import 'package:life_pilot/calendar/controller_calendar.dart';
import 'package:life_pilot/pages/home/model/dashboard/model_dashboard.dart';
import 'package:life_pilot/utils/api.dart';
import 'package:life_pilot/utils/enum.dart';
import 'package:life_pilot/utils/logger.dart';
import 'package:life_pilot/auth/service_auth.dart';
import 'package:life_pilot/utils/const.dart';
import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';

class ControllerAuth extends ChangeNotifier {
  final ControllerCalendar? controllerCalendar;
  final ModelDashboard? modelDashboard;
  StreamSubscription<AuthState>? _authSubscription;
  ControllerAuth({this.controllerCalendar, this.modelDashboard});

  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }
    _initialized = true;
    _listenAuthState();
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
      }
    });
  }

  // -------------------- 狀態 --------------------
  bool _isLoading = true;
  bool _isLoggedIn = false;
  bool _isAnonymous = false;
  String? _currentAccount;
  AuthPage _currentPage = AuthPage.login;

  bool get isLoading => _isLoading;
  bool get isLoggedIn => _isLoggedIn;
  bool get isAnonymous => _isAnonymous;
  String? get currentAccount => _currentAccount;
  bool get hasServerAdminRole =>
      supabase.auth.currentUser?.appMetadata['role'] == AuthConstants.adminRole;
  bool get isSysAdmin => hasServerAdminRole;
  AuthPage get currentPage => _currentPage;

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

    // 🧹 若帳號不同，清空並重新載入日曆資料
    if (!_isLoggedIn) {
      controllerCalendar?.clearAll();
      modelDashboard?.switchAccount(null);
    } else if (_currentAccount != oldAccount) {
      controllerCalendar?.clearAll();
      modelDashboard?.switchAccount(_currentAccount);
      await controllerCalendar?.loadCalendarEvents(month: DateTime.now());
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
    super.dispose();
  }
}
