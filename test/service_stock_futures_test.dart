import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/stock/service_stock.dart';
import 'package:life_pilot/stock/repository_stock_futures.dart';

class _Repository extends RepositoryStockFutures {
  List<Map<String, dynamic>> current = [], previous = [];
  int currentReads = 0, previousReads = 0;
  Object? failure;
  @override
  Future<List<Map<String, dynamic>>> readDate(DateTime date) async {
    currentReads++;
    return current;
  }

  @override
  Future<List<Map<String, dynamic>>> readPreviousDate(
    DateTime date, {
    required int lookbackDays,
  }) async {
    previousReads++;
    expect(lookbackDays, 14);
    if (failure != null) throw failure!;
    return previous;
  }
}

void main() {
  final date = DateTime(2026, 8, 20);
  Map<String, dynamic> row(int qty) => {
    'product_name': '臺股期貨',
    'identity_type': 'foreign investor',
    'oi_long_qty': 800,
    'oi_short_qty': 300,
    'oi_net_qty': qty,
  };
  test('empty current day skips all historical queries', () async {
    final repo = _Repository();
    expect(
      await ServiceStock(futuresRepository: repo).selectFutures(date),
      isEmpty,
    );
    expect(repo.currentReads, 1);
    expect(repo.previousReads, 0);
  });
  test('missing history does not create a false position change', () async {
    final repo = _Repository()..current = [row(500)];
    final rows = await ServiceStock(
      futuresRepository: repo,
    ).selectFutures(date);
    expect(rows.single.oiNetQtyDiff, 0);
    expect(repo.previousReads, 1);
  });
  test('nearest historical result supplies the comparison values', () async {
    final repo = _Repository()
      ..current = [row(500)]
      ..previous = [row(200)];
    final rows = await ServiceStock(
      futuresRepository: repo,
    ).selectFutures(date);
    expect(rows.single.oiNetQtyDiff, 300);
    expect(repo.currentReads, 1);
    expect(repo.previousReads, 1);
  });
  test('historical query errors are not disguised as zero change', () async {
    final repo = _Repository()
      ..current = [row(500)]
      ..failure = StateError('offline');
    await expectLater(
      ServiceStock(futuresRepository: repo).selectFutures(date),
      throwsStateError,
    );
  });
}
