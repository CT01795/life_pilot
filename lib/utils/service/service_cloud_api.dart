import 'dart:async';
import 'dart:collection';
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
    DateTime Function()? now,
  }) : _client = client,
       _now = now ?? DateTime.now;

  static const int _maxCachedReads = 64;

  final SupabaseClient? _client;
  final DateTime Function() _now;
  final Duration timeout;
  final LinkedHashMap<String, _CloudReadCacheEntry> _readCache =
      LinkedHashMap<String, _CloudReadCacheEntry>();
  final Map<String, Future<dynamic>> _inFlightReads = {};

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

    final cacheDuration = _cacheDuration(route);
    if (cacheDuration == null) {
      return _send(
        client: client,
        route: route,
        method: method,
        body: body,
        requestToken: requestToken,
        sameSession: sameSession,
      );
    }

    final key = '${session.user.id}|$method|$route|${_stableJson(body)}';
    _removeExpiredReads();
    final cached = _readCache.remove(key);
    if (cached != null && cached.expiresAt.isAfter(_now())) {
      _readCache[key] = cached;
      return cached.value;
    }

    final existing = _inFlightReads[key];
    if (existing != null) return existing;

    final request =
        _send(
          client: client,
          route: route,
          method: method,
          body: body,
          requestToken: requestToken,
          sameSession: sameSession,
        ).then((value) {
          _readCache[key] = _CloudReadCacheEntry(
            value: value,
            expiresAt: _now().add(cacheDuration),
          );
          _trimReadCache();
          return value;
        });
    _inFlightReads[key] = request;
    void clearInFlight() {
      if (identical(_inFlightReads[key], request)) _inFlightReads.remove(key);
    }

    unawaited(
      request.then<void>(
        (_) => clearInFlight(),
        onError: (Object _, StackTrace _) => clearInFlight(),
      ),
    );
    return request;
  }

  Future<dynamic> _send({
    required SupabaseClient client,
    required String route,
    required String method,
    required Map<String, dynamic> body,
    required String requestToken,
    required bool Function() sameSession,
  }) async {
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

  Duration? _cacheDuration(String route) => switch (route) {
    'external/weather' => const Duration(minutes: 5),
    'external/holidays' => const Duration(hours: 1),
    'external/geocode' => const Duration(hours: 24),
    'event/get_public_event_url_data' => const Duration(minutes: 15),
    _ => null,
  };

  void _removeExpiredReads() {
    final now = _now();
    _readCache.removeWhere((_, entry) => !entry.expiresAt.isAfter(now));
  }

  void _trimReadCache() {
    while (_readCache.length > _maxCachedReads) {
      _readCache.remove(_readCache.keys.first);
    }
  }

  static String _stableJson(Object? value) {
    Object? normalize(Object? current) {
      if (current is Map) {
        final keys = current.keys.map((key) => key.toString()).toList()..sort();
        return <String, Object?>{
          for (final key in keys) key: normalize(current[key]),
        };
      }
      if (current is List) return current.map(normalize).toList();
      return current;
    }

    return jsonEncode(normalize(value));
  }
}

class _CloudReadCacheEntry {
  const _CloudReadCacheEntry({required this.value, required this.expiresAt});

  final dynamic value;
  final DateTime expiresAt;
}
