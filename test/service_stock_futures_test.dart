import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/stock/service_stock.dart';
import 'package:life_pilot/utils/service/service_api.dart';

void main() {
  test('futures lookup stops after fourteen missing historical days', () async {
    final api = _QueuedServiceApi(List.generate(15, (_) => <dynamic>[]));
    final service = ServiceStock(supabaseApi: api);

    final futures = await service.selectFutures(DateTime(2026, 8, 20));

    expect(futures, isEmpty);
    expect(api.requestedDates, hasLength(15));
    expect(api.requestedDates.first, '2026-08-20');
    expect(api.requestedDates.last, '2026-08-06');
  });

  test('futures lookup stops as soon as historical data is found', () async {
    final api = _QueuedServiceApi([
      <dynamic>[],
      <dynamic>[],
      <dynamic>[],
      [
        {
          'product_name': 'historical product',
          'identity_type': 'foreign investor',
          'oi_net_qty': 100,
        },
      ],
    ]);
    final service = ServiceStock(supabaseApi: api);

    await service.selectFutures(DateTime(2026, 8, 20));

    expect(api.requestedDates, [
      '2026-08-20',
      '2026-08-19',
      '2026-08-18',
      '2026-08-17',
    ]);
  });

  test('missing historical data does not create a false position change',
      () async {
    final api = _QueuedServiceApi([
      [
        {
          'product_name': '\u81fa\u80a1\u671f\u8ca8',
          'identity_type': 'foreign investor',
          'oi_long_qty': 800,
          'oi_short_qty': 300,
          'oi_net_qty': 500,
        },
      ],
      ...List.generate(14, (_) => <dynamic>[]),
    ]);
    final service = ServiceStock(supabaseApi: api);

    final futures = await service.selectFutures(DateTime(2026, 8, 20));

    expect(futures, hasLength(1));
    expect(futures.single.oiNetQty, 500);
    expect(futures.single.oiNetQtyDiff, 0);
    expect(api.requestedDates, hasLength(15));
  });
}

class _QueuedServiceApi extends ServiceApi {
  _QueuedServiceApi(this.responses) : super('https://example.invalid');

  final List<dynamic> responses;
  final List<String> requestedDates = [];
  int _nextResponse = 0;

  @override
  Future<dynamic> post(
    String path,
    Map<String, dynamic> body, {
    String? bearerToken,
  }) async {
    expect(path, 'stock/select_futures_institutional');
    requestedDates.add(body['date'] as String);
    return responses[_nextResponse++];
  }
}
