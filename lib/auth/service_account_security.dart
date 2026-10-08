import 'package:life_pilot/utils/api.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

enum AccountPasswordFailure {
  noSignedInUser,
  incorrectCurrentPassword,
  sameAsCurrent,
  weakPassword,
  reauthenticationRequired,
  unknown,
}

class AccountPasswordException implements Exception {
  const AccountPasswordException(this.failure);

  final AccountPasswordFailure failure;
}

class ServiceAccountSecurity {
  static const administratorEmail = 'minavi@alumni.nccu.edu.tw';

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final email = supabase.auth.currentUser?.email;
    if (email == null || email.isEmpty) {
      throw const AccountPasswordException(
        AccountPasswordFailure.noSignedInUser,
      );
    }
    if (currentPassword == newPassword) {
      throw const AccountPasswordException(
        AccountPasswordFailure.sameAsCurrent,
      );
    }

    try {
      await supabase.auth.updateUser(
        _PasswordUserAttributes(
          password: newPassword,
          currentPassword: currentPassword,
        ),
      );
    } on AuthException catch (error) {
      throw AccountPasswordException(_mapPasswordError(error));
    }
  }

  static AccountPasswordFailure _mapPasswordError(AuthException error) {
    final code = error.code?.toLowerCase() ?? '';
    final message = error.message.toLowerCase();

    if (code == 'same_password' ||
        message.contains('same password') ||
        message.contains('different from the old password')) {
      return AccountPasswordFailure.sameAsCurrent;
    }
    if (code == 'weak_password' ||
        message.contains('weak password') ||
        message.contains('password should be at least') ||
        message.contains('password must contain') ||
        message.contains('known to be weak')) {
      return AccountPasswordFailure.weakPassword;
    }
    if (code == 'reauthentication_needed' ||
        code == 'reauthentication_not_valid' ||
        message.contains('reauthentication') ||
        message.contains('reauthenticate') ||
        message.contains('nonce')) {
      return AccountPasswordFailure.reauthenticationRequired;
    }
    if (code == 'invalid_credentials' ||
        code == 'bad_password' ||
        message.contains('current password') ||
        message.contains('invalid login credentials') ||
        message.contains('invalid password')) {
      return AccountPasswordFailure.incorrectCurrentPassword;
    }
    return AccountPasswordFailure.unknown;
  }

  Future<String> createTemporaryPasswordForUser(String email) async {
    final response = await apiSupabase.post('/account/admin/reset-password', {
      'email': email.trim(),
    });
    if (response is! Map) {
      throw const FormatException('Invalid administrator reset response');
    }
    final password = response['temporary_password']?.toString() ?? '';
    if (password.isEmpty) {
      throw const FormatException('Temporary password is missing');
    }
    return password;
  }

  Future<String> createAccountForUser({
    required String email,
    required String accountType,
  }) async {
    final response = await apiSupabase.post('/account/admin/create-user', {
      'email': email.trim(),
      'account_type': accountType == 'vendor' ? 'vendor' : 'personal',
    });
    if (response is! Map) {
      throw const FormatException('Invalid administrator account response');
    }
    final password = response['temporary_password']?.toString() ?? '';
    if (password.isEmpty) {
      throw const FormatException('Temporary password is missing');
    }
    return password;
  }

  Future<bool> contactAdministrator({
    required String subject,
    required String body,
  }) {
    final uri = Uri(
      scheme: 'mailto',
      path: administratorEmail,
      queryParameters: {'subject': subject, 'body': body},
    );
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

// gotrue 2.20.0 does not expose currentPassword yet, although the Auth API
// accepts and may require current_password. Keep the compatibility wrapper
// until the project's SDK version exposes the field directly.
class _PasswordUserAttributes extends UserAttributes {
  _PasswordUserAttributes({
    required super.password,
    required this.currentPassword,
  });

  final String currentPassword;

  @override
  Map<String, dynamic> toJson() {
    return {...super.toJson(), 'current_password': currentPassword};
  }
}
