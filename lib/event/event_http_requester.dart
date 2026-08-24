import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

class EventHttpRequester {
  EventHttpRequester({
    http.Client? client,
    this.timeout = const Duration(seconds: 20),
    this.retryDelay = const Duration(milliseconds: 500),
    this.maxAttempts = 2,
  }) : _client = client ?? http.Client();

  final http.Client _client;
  final Duration timeout;
  final Duration retryDelay;
  final int maxAttempts;

  Future<http.Response> get(
    Uri uri, {
    Map<String, String>? headers,
  }) {
    return _send(() => _client.get(uri, headers: headers));
  }

  Future<http.Response> post(
    Uri uri, {
    Map<String, String>? headers,
    Object? body,
    Encoding? encoding,
  }) {
    return _send(
      () => _client.post(
        uri,
        headers: headers,
        body: body,
        encoding: encoding,
      ),
    );
  }

  Future<http.Response> _send(
    Future<http.Response> Function() request,
  ) async {
    final attempts = maxAttempts < 1 ? 1 : maxAttempts;
    for (var attempt = 1; attempt <= attempts; attempt++) {
      try {
        final response = await request().timeout(timeout);
        final shouldRetry = response.statusCode >= 500 &&
            response.statusCode <= 599 &&
            attempt < attempts;
        if (!shouldRetry) return response;
      } on TimeoutException {
        if (attempt >= attempts) rethrow;
      } on http.ClientException {
        if (attempt >= attempts) rethrow;
      }

      if (retryDelay > Duration.zero) {
        await Future<void>.delayed(retryDelay);
      }
    }

    throw StateError('Event HTTP request exhausted all attempts.');
  }
}
