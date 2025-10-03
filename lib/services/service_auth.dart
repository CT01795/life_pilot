import 'package:firebase_auth/firebase_auth.dart';
import 'package:life_pilot/utils/utils_common_function.dart';
import 'package:life_pilot/utils/core/utils_enum.dart';

class ServiceAuth {
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // 🔐 Check if user is logged in
  static bool isLoggedIn() => _auth.currentUser != null;

  static String? currentAccount() => _auth.currentUser?.email;

  // 🔑 Login with email/password
  static Future<String?> login(String email, String password) async {
    final error = _checkEmptyFields(email, password);
    if (error != null) {
      return error ;
    }

    return _handle(() async {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
    }, defaultError: ErrorFields.loginError);
  }

  // 🧑‍🦯 Login anonymously
  static Future<String?> anonymousLogin() async {
    return _handle(() async {
      await _auth.signInAnonymously();
    }, defaultError: ErrorFields.loginError);
  }

  static Future<String?> register(String email, String password) async {
    final error = _checkEmptyFields(email, password);
    if (error != null) {
      return error;
    }

    return _handle(() async {
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      await userCredential.user?.sendEmailVerification();
    }, defaultError: ErrorFields.registerError);
  }

  // 🔄 重設密碼
  static Future<String?> resetPassword(String email) async {
    if (email.isEmpty) {
      return ErrorFields.noEmailError;
    }

    return _handle(() async {
      await _auth.sendPasswordResetEmail(email: email);
    }, defaultError: ErrorFields.loginError);
  }  

  // 🚪 Sign out
  static Future<String?> logout() async {
    return _handle(() async {
      await _auth.signOut();
    }, defaultError: ErrorFields.logoutError);
  }

  // -------------------------
  // 🔧 Private Helper Methods
  // -------------------------
  static String? _checkEmptyFields(String email, String password) {
    if (email.isEmpty) {
      return ErrorFields.noEmailError;
    }
    if (password.isEmpty) {
      return ErrorFields.noPasswordError;
    }
    return null;
  }

  static Future<String?> _handle(
    Future<void> Function() action, {
    required String defaultError,
  }) async {
    try {
      await action();
      return null;
    } on FirebaseAuthException catch (e) {
      return _mapFirebaseAuthError(e, defaultError);
    } catch (e) {
      logger.e("${ErrorFields.unexpectedError}: $e");
      return defaultError;
    }
  }

  static String _mapFirebaseAuthError(
      FirebaseAuthException e, String defaultError) {
    logger.d("${ErrorFields.authError}: ${e.code}");

    switch (e.code) {
      case ErrorFields.userNotFoundError:
      case ErrorFields.wrongPasswordError:
      case ErrorFields.invalidCredentialError:
        return ErrorFields.wrongUserPassword; // 帳號密碼錯誤
      case ErrorFields.tooManyRequestsError: // 登入過於頻繁
      case ErrorFields.networkRequestFailedError: //網路錯誤
      case ErrorFields.invalidEmailError: // 帳號格式錯誤
      case ErrorFields.emailAlreadyInUseError: // 帳號已經被人註冊
      case ErrorFields.weakPasswordError: // Password should be at least 6 characters
        return e.code; 
      default:
        return defaultError; // 其他錯誤
    }
  }
}
