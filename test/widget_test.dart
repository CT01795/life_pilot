import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/apps/config_app.dart';
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
}
