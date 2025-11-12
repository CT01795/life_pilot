import 'package:flutter/material.dart';
import 'package:life_pilot/controllers/auth/controller_auth.dart';
import 'package:life_pilot/core/const.dart';
import 'package:life_pilot/l10n/app_localizations.dart';

class ModelAuthView extends ChangeNotifier {
  final ControllerAuth _auth;

  ModelAuthView(this._auth) {
    _auth.addListener(notifyListeners); // 觀察底層 controller 變化
  }

  @override
  void dispose() {
    _auth.removeListener(notifyListeners);
    super.dispose();
  }

  // -------------------- getters --------------------
  bool get isLoading => _auth.isLoading;
  bool get isLoggedIn => _auth.isLoggedIn;
  String? get account => _auth.currentAccount;
  AuthPage get currentPage => _auth.currentPage;

  String? getRegisterEmail() => _auth.registerMap[AuthConstants.email];
  String? getRegisterPassword() => _auth.registerMap[AuthConstants.password];

  Future<void> checkLoginStatus() => _auth.checkLoginStatus();
  Future<void> logout() => _auth.logout();
  Future<String?> login({required String email, required String password}) =>
      _auth.login(email: email, password: password);
  Future<String?> anonymousLogin() => _auth.anonymousLogin();

  Future<String?> resetPassword({required String email}) =>
      _auth.resetPassword(email: email);
  Future<String?> register({required String email, required String password}) =>
      _auth.register(email: email, password: password);

  void goToRegister(String? email, String? password) =>
      _auth.goToRegister(email: email, password: password);

  void goBackToLogin(String email, String password) =>
      _auth.goBackToLogin(email: email, password: password);

  // 登入錯誤顯示
  String showLoginError(
      {required String message, required AppLocalizations loc}) {
    final errorMap = {
      ErrorFields.wrongUserPassword: loc.wrongUserPassword,
      ErrorFields.tooManyRequestsError: loc.tooManyRequests,
      ErrorFields.networkRequestFailedError: loc.networkError,
      ErrorFields.invalidEmailError: loc.invalidEmail,
      ErrorFields.noEmailError: loc.noEmailError,
      ErrorFields.noPasswordError: loc.noPasswordError,
      ErrorFields.loginError: loc.loginError,
      ErrorFields.resetPasswordEmailNotFoundError:
          loc.resetPasswordEmailNotFound,
      ErrorFields.emailAlreadyInUseError: loc.emailAlreadyInUse,
      ErrorFields.weakPasswordError: loc.weakPassword,
      ErrorFields.registerError: loc.registerError,
      ErrorFields.logoutError: loc.logoutError,
    };
    final errorMessage = errorMap[message] ?? loc.unknownError;
    return errorMessage;
  }
}

