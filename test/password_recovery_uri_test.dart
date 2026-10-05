import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/auth/service_auth.dart';

void main() {
  test('recognizes the explicit web recovery marker', () {
    expect(
      ServiceAuth.isPasswordRecoveryUri(
        Uri.parse('https://example.com/life_pilot/?recovery=1&code=abc'),
      ),
      isTrue,
    );
  });

  test('recognizes native and implicit recovery links', () {
    expect(
      ServiceAuth.isPasswordRecoveryUri(
        Uri.parse('lifepilot://reset-password'),
      ),
      isTrue,
    );
    expect(
      ServiceAuth.isPasswordRecoveryUri(
        Uri.parse('https://example.com/#type=recovery&access_token=abc'),
      ),
      isTrue,
    );
  });

  test('does not treat an ordinary signed-in URL as recovery', () {
    expect(
      ServiceAuth.isPasswordRecoveryUri(
        Uri.parse('https://example.com/life_pilot/'),
      ),
      isFalse,
    );
  });
}
