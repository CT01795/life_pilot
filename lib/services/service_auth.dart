import 'package:firebase_auth/firebase_auth.dart';
import 'package:logger/logger.dart';

class ServiceAuth {
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // 共用的空值檢查
  static String? _checkEmptyFields(String email, String password) {
    if (email.isEmpty) {
      return 'noEmailError';
    }
    if (password.isEmpty) {
      return 'noPasswordError';
    }
    return null;
  }

  // 共用的錯誤處理邏輯
  static String _handleFirebaseAuthException(
      FirebaseAuthException e, String defaultError) {
    Logger().d("Error: $e ${e.code}");
    switch (e.code) {
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'wrongUserPassword'; // 帳號密碼錯誤
      case 'too-many-requests':
        return 'tooManyRequests'; // 登入過於頻繁
      case 'network-request-failed':
        return 'networkError'; // 網路錯誤
      case 'invalid-email':
        return 'invalidEmail'; // 帳號格式錯誤
      case 'email-already-in-use':
        return 'emailAlreadyInUse'; // 帳號已經被人註冊
      case 'weak-password':
        return 'weakPassword'; // Password should be at least 6 characters
      default:
        return defaultError; // 其他錯誤
    }
  }

  /// 檢查是否已登入
  static Future<bool> isLoggedIn() async {
    return _auth.currentUser != null;
  }

  /// 登入
  static Future<String?> login(String email, String password) async {
    final emptyCheckResult = _checkEmptyFields(email, password);
    if (emptyCheckResult != null) {
      return emptyCheckResult;
    }

    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
      return null;
    } on FirebaseAuthException catch (e) {
      return _handleFirebaseAuthException(e, 'loginError');
    } catch (e) {
      // 捕捉其他類型的錯誤
      Logger().d("Unexpected error: $e");
      return 'loginError'; // 其他錯誤
    }
  }

  static Future<String?> anonymousLogin() async {
    try {
      await _auth.signInAnonymously();
      return null;
    } on FirebaseAuthException catch (e) {
      return _handleFirebaseAuthException(e, 'loginError');
    } catch (e) {
      Logger().d("Unexpected error: $e");
      return 'loginError';
    }
  }

  /// 重設密碼
  static Future<String?> resetPassword(String email) async {
    if (email.isEmpty) {
      return 'noEmailError';
    }

    try {
      await _auth.sendPasswordResetEmail(email: email);
      return null;
    } on FirebaseAuthException catch (e) {
      return _handleFirebaseAuthException(e, 'loginError');
    } catch (e) {
      // 捕捉其他類型的錯誤
      Logger().d("Unexpected error: $e");
      return 'loginError'; // 其他錯誤
    }
  }

  static Future<String?> register(String email, String password) async {
    final emptyCheckResult = _checkEmptyFields(email, password);
    if (emptyCheckResult != null) {
      return emptyCheckResult;
    }

    try {
      UserCredential userCredential = await _auth
          .createUserWithEmailAndPassword(email: email, password: password);
      // 發送電子郵件驗證
      await userCredential.user?.sendEmailVerification();
      return null;
    } on FirebaseAuthException catch (e) {
      return _handleFirebaseAuthException(e, 'registerError');
    } catch (e) {
      // 捕捉其他類型的錯誤
      Logger().d("Unexpected error: $e");
      return 'registerError'; // 其他錯誤
    }
  }

  /// 登出
  static Future<String?> logout() async {
    try {
      await _auth.signOut();
      return null;
    } catch (e) {
      // 捕捉其他類型的錯誤
      Logger().d("Unexpected error: $e");
      return 'logoutError'; // 其他錯誤
    }
  }

  static Future<String?> currentAccount() async {
    return _auth.currentUser?.email;
  }
}
