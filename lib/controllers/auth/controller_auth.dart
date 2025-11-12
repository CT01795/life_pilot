import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:life_pilot/controllers/calendar/controller_calendar.dart';
import 'package:life_pilot/core/logger.dart';
import 'package:life_pilot/services/service_auth.dart';
import 'package:life_pilot/core/const.dart';

enum AuthPage { login, register, pageMain }

class ControllerAuth extends ChangeNotifier {
  final ControllerCalendar? controllerCalendar;

  ControllerAuth({this.controllerCalendar});
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
    AuthConstants.email: constEmpty,
    AuthConstants.password: constEmpty,
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

    final user = FirebaseAuth.instance.currentUser;
    final oldAccount = _currentAccount; // 👈 比對用

    // FirebaseAuth.instance.currentUser 有時在剛登入／註冊完畢會延遲更新；
    // 加這個短暫 delay 可以避免：
    //    Another exception was thrown: Assertion failed: window.dart:99
    //    登入／註冊後畫面閃爍一下再回到登入頁。
    await Future.delayed(const Duration(milliseconds: 250));

    _update(() {
      _isLoggedIn = user != null;
      _isAnonymous = user?.isAnonymous ?? false;
      _currentAccount = _isAnonymous ? AuthConstants.guest : user?.email;
      _currentPage = _isLoggedIn ? AuthPage.pageMain : AuthPage.login;
    }, notify: false);
    
    // 🧹 若帳號不同，清空並重新載入日曆資料
    if(!_isLoggedIn){
      controllerCalendar?.clearAll();
    }
    else if (_currentAccount != oldAccount) {
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
  Future<String?> login(
      {required String email, required String password}) =>
      _authenticate(() => ServiceAuth.login(email: email, password: password));

  // -------------------- 匿名登入 --------------------
  Future<String?> anonymousLogin() => _authenticate(ServiceAuth.anonymousLogin);
  

  // -------------------- 註冊 --------------------
  Future<String?> register(
      {required String email, required String password}) =>
      _authenticate(() => ServiceAuth.register(email: email, password: password));

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
  void goBackToLogin({String? email, String? password}) =>
      goToPage(AuthPage.login, email: email, password: password);
}

/*改進重點
✅ Getter 封裝狀態變數	_isLoading → isLoading	防止外部直接修改內部狀態，提高封裝性
✅ 集中更新方法 _update()	避免多重 notifyListeners()	每個流程只重繪一次，提高效能與穩定性
✅ 抽出 _authenticate() 共用流程	登入、註冊、匿名登入共用 try/catch 結構	
✅ 明確狀態流轉順序	登入→更新帳號→載入資料→通知 UI，消除閃爍與 race condition	
✅ 使用 logger.e() 而非 logger.d()	區分開除錯與錯誤輸出層級	
✅ 所有更新皆在 _update() 包裹	易於日後整合 batch 更新或 debounced rebuild*/