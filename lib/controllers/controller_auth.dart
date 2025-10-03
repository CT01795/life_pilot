import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:life_pilot/controllers/controller_calendar.dart';
import 'package:life_pilot/utils/core/utils_locator.dart';
import 'package:life_pilot/services/service_auth.dart';
import 'package:life_pilot/utils/core/utils_const.dart';

enum AuthPage { login, register, pageMain }

class ControllerAuth extends ChangeNotifier {
  //----------------------「Auth 狀態管理器」管理登入狀態、登出等全局驗證狀態 ----------------------
  bool _isLoading = true;
  bool _isLoggedIn = false;
  String? _currentAccount;
  bool _isAnonymous = false;

  AuthPage _currentPage = AuthPage.login;
  final Map<String, String> _registerBackData = {
    constEmail: constEmpty,
    constPassword: constEmpty
  };

  // Getters
  bool get isLoading => _isLoading;
  bool get isLoggedIn => _isLoggedIn;
  String? get currentAccount => _currentAccount;
  bool get isAnonymous => _isAnonymous;
  AuthPage get currentPage => _currentPage;
  Map<String, String> get registerBackData => _registerBackData;

  Future<void> checkLoginStatus() async {
    // 🟡 延後通知，先更新狀態，不要立即 notify
    _isLoading = true;
    notifyListeners();
    
    final user = FirebaseAuth.instance.currentUser;
    final prevAccount = _currentAccount; // 👈 比對用

    _isLoggedIn = user != null;
    _isAnonymous = user?.isAnonymous ?? false;
    if (user != null && !user.isAnonymous) {
      _currentAccount = user.email;
    } else if (_isAnonymous) {
      _currentAccount = constGuest;
    }

    // ✅ 如果帳號不同，清除 Calendar 並載入新資料
    if (_currentAccount != prevAccount) {
      final calendar = getIt<ControllerCalendar>();
      calendar.clearAll();
      await calendar.loadCalendarEvents(); // 重新載入
    }

    _isLoading = false;
    _currentPage = _isLoggedIn ? AuthPage.pageMain : AuthPage.login;
    // ✅ 等全部狀態都準備好再一次性更新 UI
    notifyListeners();
  }

  Future<String?> anonymousLogin() async {
    _isLoading = true;
    notifyListeners();

    final result = await ServiceAuth.anonymousLogin();
    if (result == null) {
      await checkLoginStatus();
    }

    _isLoading = false;
    notifyListeners();
    return result;
  }

  Future<void> logout({VoidCallback? onLogoutComplete}) async {
    _isLoading = true;
    notifyListeners();

    await ServiceAuth.logout();
    if(_currentAccount != null && !_isAnonymous) _registerBackData[constEmail] = _currentAccount!;
    _clearUserData();

    getIt<ControllerCalendar>().clearAll(); // 🧹 登出也清除資料
    _isLoading = false;
    _currentPage = AuthPage.login;
    notifyListeners();

    // 🟢 使用 WidgetsBinding 保證畫面已經 mount，再執行登出邏輯（例如跳頁）
    if (onLogoutComplete != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        onLogoutComplete();
      });
    }
  }

  void _clearUserData() {
    _isLoggedIn = false;
    _isAnonymous = false;
    _currentAccount = null;
  }

  void goToRegister({String? email, String? password}) {
    if (email != null) _registerBackData[constEmail] = email;
    if (password != null) _registerBackData[constPassword] = password;
    _currentPage = AuthPage.register;
    notifyListeners();
  }

  void goBackToLogin({required String? email, required String? password}) {
    if (email != null) _registerBackData[constEmail] = email;
    if (password != null) _registerBackData[constPassword] = password;
    _currentPage = AuthPage.login;
    notifyListeners();
  }

  void setPage(AuthPage page) {
    _currentPage = page;
    notifyListeners();
  }
}
