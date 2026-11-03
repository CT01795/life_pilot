import 'package:life_pilot/auth/service_account_security.dart';
import 'package:life_pilot/utils/safe_change_notifier.dart';

enum AccountMailRequestResult {
  opened,
  unavailable,
  invalidEmail,
  disabled,
  registered,
  statusUnavailable,
}

/// Opens a user-reviewed email draft; never creates an account or sends Auth mail.
class ControllerAccountMailRequest extends SafeChangeNotifier {
  ControllerAccountMailRequest({required ServiceAccountSecurity service})
    : _service = service;
  final ServiceAccountSecurity _service;
  static final _email = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
  bool sending = false;

  Future<AccountMailRequestResult?> send({
    required String email,
    required String subject,
    required String body,
    bool checkRegistrationEligibility = false,
  }) async {
    if (notifierDisposed || sending) return null;
    if (!_email.hasMatch(email.trim())) {
      return AccountMailRequestResult.invalidEmail;
    }
    sending = true;
    notifyListeners();
    try {
      if (checkRegistrationEligibility) {
        try {
          final status = await _service.registrationEmailStatus(email);
          if (notifierDisposed) return null;
          switch (status) {
            case RegistrationEmailStatus.disabled:
              return AccountMailRequestResult.disabled;
            case RegistrationEmailStatus.registered:
              return AccountMailRequestResult.registered;
            case RegistrationEmailStatus.invalid:
              return AccountMailRequestResult.invalidEmail;
            case RegistrationEmailStatus.available:
              break;
          }
        } catch (_) {
          return notifierDisposed
              ? null
              : AccountMailRequestResult.statusUnavailable;
        }
      }
      final opened = await _service.contactAdministrator(
        subject: subject,
        body: body,
      );
      if (notifierDisposed) return null;
      return opened
          ? AccountMailRequestResult.opened
          : AccountMailRequestResult.unavailable;
    } catch (_) {
      return notifierDisposed ? null : AccountMailRequestResult.unavailable;
    } finally {
      if (!notifierDisposed) {
        sending = false;
        notifyListeners();
      }
    }
  }
}
