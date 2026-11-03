import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/auth/controller_account_mail_request.dart';
import 'package:life_pilot/auth/service_account_security.dart';

class _MailService extends ServiceAccountSecurity {
  RegistrationEmailStatus status = RegistrationEmailStatus.available;
  bool statusUnavailable = false;
  @override
  Future<RegistrationEmailStatus> registrationEmailStatus(String email) async {
    if (statusUnavailable) throw StateError('Status unavailable');
    return status;
  }

  final result = Completer<bool>();
  final drafts = <({String subject, String body})>[];

  @override
  Future<bool> contactAdministrator({
    required String subject,
    required String body,
  }) {
    drafts.add((subject: subject, body: body));
    return result.future;
  }
}

void main() {
  test('registration opens mail only for an available address', () async {
    final service = _MailService()..status = RegistrationEmailStatus.disabled;
    final controller = ControllerAccountMailRequest(service: service);
    addTearDown(controller.dispose);
    Future<AccountMailRequestResult?> register() => controller.send(
      email: 'person@example.com',
      subject: 'Registration',
      body: '',
      checkRegistrationEligibility: true,
    );
    expect(await register(), AccountMailRequestResult.disabled);
    service.status = RegistrationEmailStatus.registered;
    expect(await register(), AccountMailRequestResult.registered);
    expect(service.drafts, isEmpty);
    service.statusUnavailable = true;
    expect(await register(), AccountMailRequestResult.statusUnavailable);
    expect(service.drafts, isEmpty);
    service.statusUnavailable = false;
    service.status = RegistrationEmailStatus.available;
    service.result.complete(true);
    expect(await register(), AccountMailRequestResult.opened);
    expect(service.drafts, hasLength(1));
  });
  for (final opened in [true, false]) {
    test(
      'valid email opens one draft and reports launcher result: $opened',
      () async {
        final service = _MailService();
        final controller = ControllerAccountMailRequest(service: service);
        addTearDown(controller.dispose);
        Future<AccountMailRequestResult?> send(String email) => controller.send(
          email: email,
          subject: 'Account request',
          body: 'person@example.com',
        );

        expect(await send('invalid'), AccountMailRequestResult.invalidEmail);
        expect(service.drafts, isEmpty);
        final pending = send('person@example.com');
        expect(await send('person@example.com'), isNull);
        expect(service.drafts.single, (
          subject: 'Account request',
          body: 'person@example.com',
        ));
        service.result.complete(opened);
        expect(
          await pending,
          opened
              ? AccountMailRequestResult.opened
              : AccountMailRequestResult.unavailable,
        );
        expect(controller.sending, isFalse);
      },
    );
  }
}
