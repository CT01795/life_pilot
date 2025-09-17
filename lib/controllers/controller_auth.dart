import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:life_pilot/services/service_auth.dart';
import 'package:life_pilot/utils/utils_const.dart';

class ControllerAuth extends ChangeNotifier {
  //----------------------「Auth 狀態管理器」管理登入狀態、登出等全局驗證狀態 ----------------------
  bool isLoading = true;
  bool isLoggedIn = false;
  String? currentAccount;
  bool isAnonymous = false;

  Future<void> checkLoginStatus() async {
    // 🟡 延後通知，先更新狀態，不要立即 notify
    isLoading = true;
    //notifyListeners();

    final user = FirebaseAuth.instance.currentUser;
    isLoggedIn = user != null;
    isAnonymous = user?.isAnonymous ?? false;
    if (user != null && !user.isAnonymous) {
      currentAccount = user.email;
    } else if (isAnonymous) {
      currentAccount = constGuest;
    }
    isLoading = false;
    // ✅ 等全部狀態都準備好再一次性更新 UI
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
    isAnonymous = false;
    currentAccount = null;
    notifyListeners();

    // 🟢 使用 WidgetsBinding 保證畫面已經 mount，再執行登出邏輯（例如跳頁）
    if (onLogoutComplete != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          onLogoutComplete();
        }
      });
    }
  }
}
