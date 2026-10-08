import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:life_pilot/auth/auth_session_guard.dart';
import 'package:life_pilot/utils/service/service_api.dart';
import 'package:life_pilot/utils/service/session_aware_http_client.dart';

void main() {
  test(
    'Supabase HTTP 401 reports an invalid session and preserves response',
    () async {
      final client = SessionAwareHttpClient(
        inner: MockClient(
          (_) async => http.Response(
            jsonEncode({'code': 'invalid_jwt', 'message': 'expired'}),
            401,
          ),
        ),
      );
      final failureFuture = AuthSessionGuard.failures.first;

      final response = await client.get(Uri.parse('https://example.com/user'));
      final failure = await failureFuture;

      expect(response.statusCode, 401);
      expect(jsonDecode(response.body), containsPair('code', 'invalid_jwt'));
      expect(failure.statusCode, 401);
      expect(failure.code, 'invalid_jwt');
      client.close();
    },
  );

  test('non-401 invalid session code is reported from shared API', () async {
    final api = ServiceApi(
      'https://example.com',
      client: MockClient(
        (_) async => http.Response(jsonEncode({'code': 'user_not_found'}), 403),
      ),
    );
    final failureFuture = AuthSessionGuard.failures.first;

    await expectLater(
      api.get('private'),
      throwsA(
        isA<ServiceApiException>().having(
          (error) => error.statusCode,
          'statusCode',
          403,
        ),
      ),
    );
    final failure = await failureFuture;

    expect(failure.statusCode, 403);
    expect(failure.code, 'user_not_found');
  });

  test('ordinary server failures do not report an invalid session', () async {
    final api = ServiceApi(
      'https://example.com',
      client: MockClient((_) async => http.Response('temporary failure', 503)),
    );
    var reported = false;
    final subscription = AuthSessionGuard.failures.listen((_) {
      reported = true;
    });

    await expectLater(api.get('health'), throwsA(isA<ServiceApiException>()));
    await Future<void>.delayed(Duration.zero);

    expect(reported, isFalse);
    await subscription.cancel();
  });
}
