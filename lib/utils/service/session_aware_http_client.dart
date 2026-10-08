import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:life_pilot/auth/auth_session_guard.dart';

/// Observes failed Supabase responses without changing their content.
///
/// Error bodies are buffered only for non-success responses, then rebuilt so
/// Supabase still receives the exact same response stream.
class SessionAwareHttpClient extends http.BaseClient {
  SessionAwareHttpClient({http.Client? inner})
    : _inner = inner ?? http.Client();

  final http.Client _inner;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final response = await _inner.send(request);
    if (response.statusCode < 400) return response;

    final bytes = await response.stream.toBytes();
    final body = utf8.decode(bytes, allowMalformed: true);
    AuthSessionGuard.reportHttpFailure(
      source: request.url.toString(),
      statusCode: response.statusCode,
      responseBody: body,
    );

    return http.StreamedResponse(
      Stream<List<int>>.value(bytes),
      response.statusCode,
      contentLength: bytes.length,
      request: response.request,
      headers: response.headers,
      isRedirect: response.isRedirect,
      persistentConnection: response.persistentConnection,
      reasonPhrase: response.reasonPhrase,
    );
  }

  @override
  void close() => _inner.close();
}
