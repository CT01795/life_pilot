import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

typedef AccessTokenProvider = String? Function();

class ServiceApiException implements Exception {
  final String path;
  final int? statusCode;
  final String message;

  const ServiceApiException({
    required this.path,
    required this.message,
    this.statusCode,
  });

  @override
  String toString() {
    final status = statusCode == null ? '' : ' (HTTP $statusCode)';
    return 'ServiceApiException$status for "$path": $message';
  }
}

class ServiceApi {
  final String baseUrl;
  final Duration timeout;
  final AccessTokenProvider? accessTokenProvider;
  final http.Client _client;

  ServiceApi(
    this.baseUrl, {
    this.timeout = const Duration(seconds: 20),
    this.accessTokenProvider,
    http.Client? client,
  }) : _client = client ?? http.Client();

  Uri buildUri(String path) {
    final normalizedBaseUrl = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    final normalizedPath = path.startsWith('/') ? path.substring(1) : path;

    return Uri.parse('$normalizedBaseUrl/$normalizedPath');
  }

  Map<String, String> _headers(String? bearerToken) {
    final providedToken = bearerToken?.trim();
    final fallbackToken = accessTokenProvider?.call()?.trim();
    final normalizedToken = providedToken != null && providedToken.isNotEmpty
        ? providedToken
        : fallbackToken;

    return {
      'Content-Type': 'application/json',
      if (normalizedToken != null && normalizedToken.isNotEmpty)
        'Authorization': 'Bearer $normalizedToken',
    };
  }

  Future<dynamic> get(
    String path, {
    String? bearerToken,
  }) async {
    late final http.Response res;

    try {
      res = await _client
          .get(
            buildUri(path),
            headers: _headers(bearerToken),
          )
          .timeout(timeout);
    } on TimeoutException {
      throw ServiceApiException(
        path: path,
        message: 'Request timed out after ${timeout.inSeconds} seconds',
      );
    }

    return _decodeResponse(path, res);
  }

  Future<dynamic> post(
    String path,
    Map<String, dynamic> body, {
    String? bearerToken,
  }) async {
    late final http.Response res;

    try {
      res = await _client
          .post(
            buildUri(path),
            headers: _headers(bearerToken),
            body: jsonEncode(body),
          )
          .timeout(timeout);
    } on TimeoutException {
      throw ServiceApiException(
        path: path,
        message: 'Request timed out after ${timeout.inSeconds} seconds',
      );
    }

    return _decodeResponse(path, res);
  }

  Future<dynamic> postWithRetry(
    String path,
    Map<String, dynamic> body, {
    String? bearerToken,
    int maxAttempts = 3,
    Duration initialDelay = const Duration(seconds: 1),
  }) async {
    if (maxAttempts < 1) {
      throw ArgumentError.value(
          maxAttempts, 'maxAttempts', 'must be at least 1');
    }

    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        return await post(path, body, bearerToken: bearerToken);
      } on http.ClientException {
        if (attempt == maxAttempts) rethrow;
      } on ServiceApiException catch (error) {
        final isTransient = error.statusCode == null ||
            error.statusCode == 502 ||
            error.statusCode == 503 ||
            error.statusCode == 504;
        if (!isTransient || attempt == maxAttempts) rethrow;
      }

      await Future<void>.delayed(initialDelay * (1 << (attempt - 1)));
    }

    throw StateError('Retry loop completed without a response');
  }

  dynamic _decodeResponse(String path, http.Response res) {
    if (res.statusCode != 200) {
      throw ServiceApiException(
        path: path,
        statusCode: res.statusCode,
        message: res.body,
      );
    }

    try {
      return jsonDecode(res.body);
    } on FormatException {
      throw ServiceApiException(
        path: path,
        statusCode: res.statusCode,
        message: 'Invalid JSON response',
      );
    }
  }
}
