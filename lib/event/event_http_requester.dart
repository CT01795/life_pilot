import 'dart:convert';

import 'package:http/http.dart' as http;

class EventHttpRequester {
  EventHttpRequester({
    http.Client? client,
    this.timeout = const Duration(seconds: 20),
  }) : _client = client ?? http.Client();

  final http.Client _client;
  final Duration timeout;

  Future<http.Response> get(
    Uri uri, {
    Map<String, String>? headers,
  }) {
    return _client.get(uri, headers: headers).timeout(timeout);
  }

  Future<http.Response> post(
    Uri uri, {
    Map<String, String>? headers,
    Object? body,
    Encoding? encoding,
  }) {
    return _client
        .post(uri, headers: headers, body: body, encoding: encoding)
        .timeout(timeout);
  }
}
