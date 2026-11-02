import 'dart:async';
import 'dart:convert';
import 'package:life_pilot/auth/auth_session_guard.dart';
import 'package:life_pilot/utils/service/service_api.dart';
import 'package:life_pilot/utils/supabase.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Secret-bearing operations execute on Supabase, never on Render or the device.
class ServiceCloudApi {
  ServiceCloudApi({
    SupabaseClient? client,
    this.timeout = const Duration(seconds: 45),
  }) : _client = client;
  final SupabaseClient? _client;
  final Duration timeout;
  Future<dynamic> get(String path, {String? bearerToken}) =>
      _invoke(path, 'GET', const {}, bearerToken);
  Future<dynamic> post(
    String path,
    Map<String, dynamic> body, {
    String? bearerToken,
  }) => _invoke(path, 'POST', body, bearerToken);
  Future<dynamic> _invoke(
    String path,
    String method,
    Map<String, dynamic> body,
    String? token,
  ) async {
    final route = path.startsWith('/') ? path.substring(1) : path;
    if (!(route.startsWith('account/') ||
            route.startsWith('external/') ||
            route.startsWith('event/')) ||
        route.contains('..') ||
        route.contains('://')) {
      throw ArgumentError.value(path, 'path');
    }
    final client = _client ?? supabase;
    final session = client.auth.currentSession;
    final requestToken = token ?? session?.accessToken;
    if (session == null ||
        requestToken == null ||
        requestToken != session.accessToken) {
      throw ServiceApiException(
        path: route,
        statusCode: 401,
        message: 'authentication_required',
      );
    }
    bool sameSession() =>
        client.auth.currentSession?.accessToken == requestToken &&
        client.auth.currentUser?.id == session.user.id;
    try {
      final response = await client.functions
          .invoke(
            'life-pilot-services',
            body: {'route': route, 'method': method, 'body': body},
            headers: {'Authorization': 'Bearer $requestToken'},
          )
          .timeout(timeout);
      if (!sameSession()) {
        throw StateError('Account changed during service request');
      }
      return response.data;
    } on FunctionException catch (error) {
      if (sameSession()) {
        AuthSessionGuard.reportHttpFailure(
          source: 'supabase:functions/$route',
          statusCode: error.status,
          responseBody: jsonEncode(error.details),
        );
      }
      throw ServiceApiException(
        path: route,
        statusCode: error.status,
        message: jsonEncode(error.details),
      );
    } on TimeoutException {
      throw ServiceApiException(
        path: route,
        message: 'Supabase service request timed out',
      );
    }
  }
}
