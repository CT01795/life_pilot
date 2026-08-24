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
    );

    expect(
      requester.get(Uri.parse('https://example.com')),
      throwsA(isA<TimeoutException>()),
    );
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
