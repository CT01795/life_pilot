import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:life_pilot/event/event_http_requester.dart';

void main() {
  test('returns a successful external event response', () async {
    final requester = EventHttpRequester(
      client: MockClient((request) async => http.Response('events', 200)),
      timeout: const Duration(milliseconds: 100),
    );

    final response = await requester.get(Uri.parse('https://example.com'));

    expect(response.statusCode, 200);
    expect(response.body, 'events');
  });

  test('times out when an external event source stops responding', () async {
    final requester = EventHttpRequester(
      client: MockClient((request) async {
        await Future<void>.delayed(const Duration(milliseconds: 100));
        return http.Response('late', 200);
      }),
      timeout: const Duration(milliseconds: 10),
      retryDelay: Duration.zero,
    );

    expect(
      requester.get(Uri.parse('https://example.com')),
      throwsA(isA<TimeoutException>()),
    );
  });

  test('retries once after a temporary server failure', () async {
    var calls = 0;
    final requester = EventHttpRequester(
      client: MockClient((request) async {
        calls++;
        return http.Response(
            calls == 1 ? 'temporary' : 'ok', calls == 1 ? 503 : 200);
      }),
      retryDelay: Duration.zero,
    );

    final response = await requester.get(Uri.parse('https://example.com'));

    expect(calls, 2);
    expect(response.statusCode, 200);
  });

  test('retries once after a connection error', () async {
    var calls = 0;
    final requester = EventHttpRequester(
      client: MockClient((request) async {
        calls++;
        if (calls == 1) throw http.ClientException('disconnected');
        return http.Response('ok', 200);
      }),
      retryDelay: Duration.zero,
    );

    final response = await requester.get(Uri.parse('https://example.com'));

    expect(calls, 2);
    expect(response.statusCode, 200);
  });

  test('returns the final server failure after retry is exhausted', () async {
    var calls = 0;
    final requester = EventHttpRequester(
      client: MockClient((request) async {
        calls++;
        return http.Response('unavailable', 503);
      }),
      retryDelay: Duration.zero,
    );

    final response = await requester.get(Uri.parse('https://example.com'));

    expect(calls, 2);
    expect(response.statusCode, 503);
  });

  test('does not retry a client or rate-limit response', () async {
    for (final statusCode in [400, 404, 429]) {
      var calls = 0;
      final requester = EventHttpRequester(
        client: MockClient((request) async {
          calls++;
          return http.Response('client error', statusCode);
        }),
        retryDelay: Duration.zero,
      );

      final response = await requester.get(Uri.parse('https://example.com'));

      expect(response.statusCode, statusCode);
      expect(calls, 1);
    }
  });

  test('POST preserves headers and form data', () async {
    late http.Request captured;
    final requester = EventHttpRequester(
      client: MockClient((request) async {
        captured = request;
        return http.Response('ok', 200);
      }),
    );

    await requester.post(
      Uri.parse('https://example.com'),
      headers: const {'Referer': 'https://example.com'},
      body: const {'page': '1'},
    );

    expect(captured.headers['Referer'], 'https://example.com');
    expect(captured.body, contains('page=1'));
  });
}
