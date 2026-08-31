import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:life_pilot/utils/api.dart';
import 'package:life_pilot/utils/const.dart';
import 'package:life_pilot/utils/logger.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ServiceAuth {
  static bool _pendingPasswordRecovery = false;
  static final StreamController<void> _passwordRecoveryController =
      StreamController<void>.broadcast();

  static Stream<void> get passwordRecoveryLinks =>
      _passwordRecoveryController.stream;

  static void markPasswordRecoveryLink() {
    _pendingPasswordRecovery = true;
    _passwordRecoveryController.add(null);
  }

  static bool consumePasswordRecoveryLink() {
    final pending = _pendingPasswordRecovery;
    _pendingPasswordRecovery = false;
    return pending;
  }

  static final RegExp _emailPattern = RegExp(
    r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
  );

  // 🔐 Check if user is logged in
  static bool isLoggedIn() => supabase.auth.currentUser != null;

  static String? currentAccount() => supabase.auth.currentUser?.email;

  // 🔑 Login with email/password
  static Future<String?> login(
      {required String email, required String password}) async {
    final error = _checkEmptyFields(email: email, password: password);
    if (error != null) {
      return error;
    }

    return _handle(() async {
      await supabase.auth.signInWithPassword(email: email, password: password);
    }, defaultError: ErrorFields.loginError);
  }

  static Future<String?> register(
      {required String email, required String password}) async {
    final error = _checkRegistrationFields(
      email: email,
      password: password,
    );
    if (error != null) {
      return error;
    }

    return _handle(() async {
      final response = await supabase.auth.signUp(
        email: email,
        password: password,
        data: const {
          'privacy_policy_version': AuthConstants.privacyPolicyVersion,
          'terms_of_service_version': AuthConstants.termsOfServiceVersion,
        },
      );
      if (response.user?.identities?.isEmpty == true) {
        throw const AuthException('User already registered');
      }
    }, defaultError: ErrorFields.registerError);
  }

  // 🔄 重設密碼
  static Future<String?> resetPassword({required String email}) async {
    if (email.isEmpty) {
      return ErrorFields.noEmailError;
    }
    if (!_emailPattern.hasMatch(email)) {
      return ErrorFields.invalidEmailError;
    }

    return _handle(() async {
      final redirectTo = kIsWeb
          ? 'https://ct01795.github.io/life_pilot/'
          : 'lifepilot://reset-password';

      await supabase.auth.resetPasswordForEmail(
        email,
        redirectTo: redirectTo,
      );
    }, defaultError: ErrorFields.resetPasswordError);
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

  static String? _checkRegistrationFields({
    required String email,
    required String password,
  }) {
    final emptyFieldError = _checkEmptyFields(
      email: email,
      password: password,
    );
    if (emptyFieldError != null) return emptyFieldError;
    if (!_emailPattern.hasMatch(email)) {
      return ErrorFields.invalidEmailError;
    }
    if (password.length < AuthConstants.minimumPasswordLength) {
      return ErrorFields.weakPasswordError;
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
    if (message.contains("invalid login credentials")) {
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
