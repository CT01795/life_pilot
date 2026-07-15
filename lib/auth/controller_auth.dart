import 'package:flutter/material.dart';
import 'package:life_pilot/calendar/controller_calendar.dart';
import 'package:life_pilot/utils/enum.dart';
import 'package:life_pilot/utils/logger.dart';
import 'package:life_pilot/auth/service_auth.dart';
import 'package:life_pilot/utils/const.dart';
import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';

class ControllerAuth extends ChangeNotifier {
  final ControllerCalendar? controllerCalendar;
  StreamSubscription<AuthState>? _authSubscription;
  ControllerAuth({this.controllerCalendar});

  bool _initialized = false;

  Future<void> initialize() async {
    if(_initialized){
      return;
    }
    _initialized = true;
    _listenAuthState();
  }

  void _listenAuthState() {
    _authSubscription =
        Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      final event = data.event;
      if (event == AuthChangeEvent.passwordRecovery) {
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
  AuthPage get currentPage => _currentPage;

  final Map<String, String> _registerMap = {
    AuthConstants.email: '',
    AuthConstants.password: '',
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

    final user = Supabase.instance.client.auth.currentUser;
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
    } else if (_currentAccount != oldAccount) {
      controllerCalendar?.clearAll();
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
      _update(() => _isLoading = false);
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
  Future<void> logout() async {
    _update(() => _isLoading = true, notify: false);

    await ServiceAuth.logout();

    if (_currentAccount != null && !_isAnonymous) {
      _registerMap[AuthConstants.email] = _currentAccount!;
    }

    _update(() {
      _isLoggedIn = false;
      _isAnonymous = false;
      _currentAccount = null;
      _currentPage = AuthPage.login;
    }, notify: false);

    controllerCalendar?.clearAll(); // 🧹 登出也清除資料

    _update(() => _isLoading = false);
  }

  // -------------------- 忘記密碼 --------------------
  Future<String?> resetPassword({required String email}) =>
      ServiceAuth.resetPassword(email: email);

  // -------------------- 頁面切換 --------------------
  void goToPage(AuthPage page, {String? email, String? password}) {
    _update(() {
      if (email != null) _registerMap[AuthConstants.email] = email;
      if (password != null) _registerMap[AuthConstants.password] = password;
      _currentPage = page;
    });
  }

  void goToRegister({String? email, String? password}) =>
      goToPage(AuthPage.register, email: email, password: password);
  void goToResetPassword({String? email, String? password}) =>
      goToPage(AuthPage.resetPassword, email: email, password: password);
  void goBackToLogin({String? email, String? password}) =>
      goToPage(AuthPage.login, email: email, password: password);

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }
}
