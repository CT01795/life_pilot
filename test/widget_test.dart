import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:life_pilot/apps/config_app.dart';
import 'package:life_pilot/stock/controller_stock.dart';
import 'package:life_pilot/stock/model_stock.dart';
import 'package:life_pilot/stock/service_stock.dart';
import 'package:life_pilot/utils/service/service_api.dart';

void main() {
  test('AppConfig exposes the Life Pilot product configuration', () {
    expect(AppConfig.appTitle, 'Life Pilot');
    expect(AppConfig.supportedLocales, contains(const Locale('zh')));
    expect(AppConfig.supportedLocales, contains(const Locale('en')));
    expect(AppConfig.supportedLocales, contains(const Locale('ja')));
    expect(AppConfig.supportedLocales, contains(const Locale('ko')));
  });

  test('ServiceApi applies a default request timeout', () {
    final api = ServiceApi('https://example.com');

    expect(api.timeout, const Duration(seconds: 20));
  });

  test('ServiceApi normalizes API URLs', () {
    final api = ServiceApi('https://example.com/');

    expect(
      api.buildUri('/stock/select_latest_stock_date').toString(),
      'https://example.com/stock/select_latest_stock_date',
    );
  });

  test('ServiceApiException includes request context', () {
    const exception = ServiceApiException(
      path: 'stock/select_latest_stock_date',
      statusCode: 500,
      message: 'Internal Server Error',
    );

    expect(exception.toString(), contains('HTTP 500'));
    expect(exception.toString(), contains('stock/select_latest_stock_date'));
  });

  test('ServiceApi sends the token supplied by its session provider', () async {
    String? authorizationHeader;
    final client = MockClient((request) async {
      authorizationHeader = request.headers['Authorization'];
      return http.Response('{}', 200);
    });
    final api = ServiceApi(
      'https://example.com',
      accessTokenProvider: () => 'session-token',
      client: client,
    );

    await api.post('/stock/predict', {});

    expect(authorizationHeader, 'Bearer session-token');
  });

  test('ServiceApi prefers an explicitly supplied token', () async {
    String? authorizationHeader;
    final client = MockClient((request) async {
      authorizationHeader = request.headers['Authorization'];
      return http.Response('{}', 200);
    });
    final api = ServiceApi(
      'https://example.com',
      accessTokenProvider: () => 'session-token',
      client: client,
    );

    await api.post(
      '/external/weather',
      {},
      bearerToken: 'explicit-token',
    );

    expect(authorizationHeader, 'Bearer explicit-token');
  });

  test('ServiceApi retries a POST after transient connection failures',
      () async {
    var attempts = 0;
    final client = MockClient((request) async {
      attempts++;
      if (attempts < 3) {
        throw http.ClientException(
          'Connection closed before full header was received',
          request.url,
        );
      }
      return http.Response('{"status":"ok"}', 200);
    });
    final api = ServiceApi('https://example.com', client: client);

    final response = await api.postWithRetry(
      '/stock/insert_stock_daily_price_batch',
      {'stocks': <dynamic>[]},
      initialDelay: Duration.zero,
    );

    expect(attempts, 3);
    expect(response['status'], 'ok');
  });

  test('ServiceApi GET sends the session token', () async {
    String? requestMethod;
    String? authorizationHeader;
    final client = MockClient((request) async {
      requestMethod = request.method;
      authorizationHeader = request.headers['Authorization'];
      return http.Response('{"status":"training"}', 200);
    });
    final api = ServiceApi(
      'https://example.com',
      accessTokenProvider: () => 'session-token',
      client: client,
    );

    final response = await api.get('/stock/model_training_status');

    expect(requestMethod, 'GET');
    expect(authorizationHeader, 'Bearer session-token');
    expect(response['status'], 'training');
  });

  test('ControllerStock handles an empty stock response', () async {
    final controller = ControllerStock(_EmptyStockService());

    await controller.load();

    expect(controller.loading, isFalse);
    expect(controller.stocks, isEmpty);
    expect(controller.updateStatus, StockUpdateStatus.succeeded);
  });

  test('ControllerStock exposes a retry state when initial sources fail',
      () async {
    final controller = ControllerStock(_FailingStockService());

    await controller.load();

    expect(controller.loading, isFalse);
    expect(controller.loadFailed, isTrue);
    expect(controller.stocks, isEmpty);
    expect(controller.updateStatus, StockUpdateStatus.idle);
  });
}

class _EmptyStockService extends ServiceStock {
  @override
  Future<List<ModelStock>> getSimpleStrategy(String level) async => [];

  @override
  Future<List<ModelStock>> getSimpleStrategySupabase(String level) async => [];

  @override
  Future<void> loadRawData() async {}
}

class _FailingStockService extends ServiceStock {
  @override
  Future<List<ModelStock>> getSimpleStrategy(String level) async {
    throw StateError('local source unavailable');
  }

  @override
  Future<List<ModelStock>> getSimpleStrategySupabase(String level) async {
    throw StateError('remote source unavailable');
  }
}
