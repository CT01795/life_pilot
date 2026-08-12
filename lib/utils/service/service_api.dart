import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

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

  ServiceApi(this.baseUrl, {this.timeout = const Duration(seconds: 20)});

  Uri buildUri(String path) {
    final normalizedBaseUrl = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    final normalizedPath = path.startsWith('/') ? path.substring(1) : path;

    return Uri.parse('$normalizedBaseUrl/$normalizedPath');
  }

  Future<dynamic> post(String path, Map<String, dynamic> body) async {
    late final http.Response res;

    try {
      res = await http.post(
        buildUri(path),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      ).timeout(timeout);
    } on TimeoutException {
      throw ServiceApiException(
        path: path,
        message: 'Request timed out after ${timeout.inSeconds} seconds',
      );
    }

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
