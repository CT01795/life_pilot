import 'dart:async';

import 'package:life_pilot/auth/service_account_security.dart';
import 'package:life_pilot/utils/supabase.dart';
import 'package:life_pilot/utils/const.dart';
import 'package:life_pilot/utils/logger.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ServiceAuth {
  static bool _pendingPasswordRecovery = false;
  static final StreamController<void> _passwordRecoveryController =
      StreamController<void>.broadcast();

  static Stream<void> get passwordRecoveryLinks =>
      _passwordRecoveryController.stream;

  static bool isPasswordRecoveryUri(Uri uri) {
    final fragment = uri.fragment;
    final fragmentQuery = fragment.contains('?')
        ? fragment.substring(fragment.indexOf('?') + 1)
        : fragment;
    Map<String, String> fragmentParameters = const {};
    try {
      fragmentParameters = Uri.splitQueryString(fragmentQuery);
    } on FormatException {
      // Supabase may briefly expose an incomplete fragment while restoring
      // the session. The explicit path/query checks below remain usable.
    }
    return uri.host == 'reset-password' ||
        uri.path.contains('reset-password') ||
        uri.queryParameters['type'] == 'recovery' ||
        uri.queryParameters['recovery'] == '1' ||
        fragmentParameters['type'] == 'recovery' ||
        fragmentParameters['recovery'] == '1';
  }

  static void capturePasswordRecoveryUri(Uri uri) {
    if (isPasswordRecoveryUri(uri)) markPasswordRecoveryLink();
  }

  static void markPasswordRecoveryLink() {
    _pendingPasswordRecovery = true;
    _passwordRecoveryController.add(null);
  }

  static bool consumePasswordRecoveryLink() {
    final pending = _pendingPasswordRecovery;
    _pendingPasswordRecovery = false;
    return pending;
  }

  static String? currentAccount() => supabase.auth.currentUser?.email;

  // 🔑 Login with email/password
  static Future<String?> login({
    required String email,
    required String password,
  }) async {
    final error = _checkEmptyFields(email: email, password: password);
    if (error != null) {
      return error;
    }

    final result = await _handle(() async {
      await supabase.auth.signInWithPassword(email: email, password: password);
    }, defaultError: ErrorFields.loginError);
    if (result == ErrorFields.wrongUserPassword) {
      try {
        if (await ServiceAccountSecurity().isEmailDisabled(email)) {
          return ErrorFields.accountDisabled;
        }
      } catch (_) {
        // Preserve the credential error if the optional lookup is unavailable.
      }
    }
    return result;
  }

  // 🚪 Sign out
  static Future<String?> logout() async {
    return _handle(() async {
      await supabase.auth.signOut();
    }, defaultError: ErrorFields.logoutError);
  }

  // -------------------------
  // 🔧 Private Helper Methods
  // -------------------------
  static String? _checkEmptyFields({
    required String email,
    required String password,
  }) {
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
      return _mapTransportError(e.toString()) ?? defaultError;
    }
  }

  static String _mapSupabaseError(AuthException e, String defaultError) {
    final message = e.message.toLowerCase();
    if (e.code == 'user_banned' || message.contains('user is banned')) {
      return ErrorFields.accountDisabled;
    }
    if (e.code == 'over_email_send_rate_limit' ||
        message.contains('email rate limit exceeded')) {
      return ErrorFields.emailRateLimitExceededError;
    }
    final transportError = _mapTransportError(message);
    if (transportError != null) return transportError;
    if (e.code == 'weak_password' || message.contains('weak password')) {
      return ErrorFields.weakPasswordError;
    }
    if (message.contains('invalid email')) {
      return ErrorFields.invalidEmailError;
    }
    if (e.code == 'invalid_credentials' ||
        message.contains("invalid login credentials")) {
      return ErrorFields.wrongUserPassword;
    }
    if (message.contains("email not confirmed")) {
      return ErrorFields.emailNotConfirmed;
    }
    if (e.code == 'email_exists' ||
        e.code == 'user_already_exists' ||
        message.contains("user already registered") ||
        message.contains("already been registered")) {
      return ErrorFields.emailAlreadyInUseError;
    }
    return defaultError;
  }

  static String? _mapTransportError(String rawMessage) {
    final message = rawMessage.toLowerCase();
    if (message.contains('too many requests') ||
        message.contains('status code 429') ||
        message.contains('statuscode: 429') ||
        message.contains('over_request_rate_limit')) {
      return ErrorFields.tooManyRequestsError;
    }
    if (message.contains('network request failed') ||
        message.contains('failed to fetch') ||
        message.contains('clientexception') ||
        message.contains('socketexception') ||
        message.contains('failed host lookup') ||
        message.contains('connection refused') ||
        message.contains('connection reset')) {
      return ErrorFields.networkRequestFailedError;
    }
    return null;
  }
}
