import 'package:life_pilot/utils/const.dart';
import 'package:life_pilot/utils/logger.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ServiceAuth {
  static final SupabaseClient _client = Supabase.instance.client;

  // 🔐 Check if user is logged in
  static bool isLoggedIn() => _client.auth.currentUser != null;

  static String? currentAccount() => _client.auth.currentUser?.email;

  // 🔑 Login with email/password
  static Future<String?> login(
      {required String email, required String password}) async {
    final error = _checkEmptyFields(email: email, password: password);
    if (error != null) {
      return error;
    }

    return _handle(() async {
      await _client.auth.signInWithPassword(email: email, password: password);
    }, defaultError: ErrorFields.loginError);
  }

  static Future<String?> register(
      {required String email, required String password}) async {
    final error = _checkEmptyFields(email: email, password: password);
    if (error != null) {
      return error;
    }

    return _handle(() async {
      await _client.auth.signUp(
        email: email,
        password: password,
      );
    }, defaultError: ErrorFields.registerError);
  }

  // 🔄 重設密碼
  static Future<String?> resetPassword({required String email}) async {
    if (email.isEmpty) {
      return ErrorFields.noEmailError;
    }

    return _handle(() async {
      await _client.auth.resetPasswordForEmail(
        email,
        redirectTo: 'https://ct01795.github.io/life_pilot/', //TODO
      );
    }, defaultError: ErrorFields.loginError);
  }

  // 🚪 Sign out
  static Future<String?> logout() async {
    return _handle(() async {
      await _client.auth.signOut();
    }, defaultError: ErrorFields.logoutError);
  }

  // -------------------------
  // 🔧 Private Helper Methods
  // -------------------------
  static String? _checkEmptyFields(
      {required String email, required String password}) {
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
    } on AuthException catch (e) {
      logger.e("Supabase Auth Error: ${e.message}");
      return _mapSupabaseError(e, defaultError);
    } catch (e) {
      logger.e("${ErrorFields.unexpectedError}: $e");
      return defaultError;
    }
  }

  static String _mapSupabaseError(AuthException e, String defaultError) {
    final message = e.message.toLowerCase();
    if (message.contains("invalid login credentials")) {
      return ErrorFields.wrongUserPassword;
    }
    if (message.contains("email not confirmed")) {
      return ErrorFields.emailNotConfirmed;
    }
    return defaultError;
  }
}
