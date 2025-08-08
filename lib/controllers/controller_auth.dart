import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:life_pilot/services/service_auth.dart';

class ControllerAuth extends ChangeNotifier {
  //----------------------「Auth 狀態管理器」管理登入狀態、登出等全局驗證狀態 ----------------------
  bool isLoading = true;
  bool isLoggedIn = false;
  String? currentAccount;
  bool isAnonymous = false;

  Future<void> checkLoginStatus() async {
    isLoading = true;
    notifyListeners();

    final user = FirebaseAuth.instance.currentUser;
    isLoggedIn = user != null;
    isAnonymous = user?.isAnonymous ?? false;
    if (user != null && !user.isAnonymous) {
      currentAccount = user.email;
    } else if (isAnonymous) {
      currentAccount = 'Guest';
    }
    isLoading = false;
    notifyListeners();
  }

  Future<String?> anonymousLogin() async {
    final result = await ServiceAuth.anonymousLogin();
    if (result == null) {
      await checkLoginStatus(); 
    }
    return result;
  }

  Future<void> logout(BuildContext context,
      {VoidCallback? onLogoutComplete}) async {
    await ServiceAuth.logout();
    isLoggedIn = false;
    currentAccount = null;
    notifyListeners();

    if (onLogoutComplete != null) {
      Future.microtask(onLogoutComplete); // ✅ 確保等畫面準備好再切換頁面
    }
  }
}
