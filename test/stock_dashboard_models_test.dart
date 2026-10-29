import 'dart:collection';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/stock/model_stock.dart';
import 'package:life_pilot/stock/model_stock_futures.dart';
import 'package:life_pilot/stock/model_stock_institutional_rankings.dart';

Map<String, dynamic> _row(
  String? product,
  String? identity,
  Object? quantity,
) => {
  'product_name': product,
  'identity_type': identity,
  'oi_long_qty': 800,
  'oi_short_qty': 300,
  'oi_net_qty': quantity,
};
List<Object?> _fields(ModelFuture row) => [
  row.productName,
  row.identityType,
  row.oiLongQty,
  row.oiShortQty,
  row.oiNetQty,
  row.oiNetQtyDiff,
];

List<ModelFuture> _legacy(
  List<Map<String, dynamic>> current,
  List<Map<String, dynamic>> previous,
) {
  final yesterday = <String, int>{
    for (final row in previous)
      '${row['product_name']}_${row['identity_type']}': row['oi_net_qty'] ?? 0,
  };
  return current
      .where((row) {
        if (!ModelStockFutures.productOrder.containsKey(row['product_name'])) {
          return false;
        }
        final quantity = row['oi_net_qty'] ?? 0;
        final old =
            yesterday['${row['product_name']}_${row['identity_type']}'] ??
            quantity;
        return !(quantity.abs() < 200 && (quantity - old).abs() < 200);
      })
      .map((row) {
        final quantity = row['oi_net_qty'] ?? 0;
        final old =
            yesterday['${row['product_name']}_${row['identity_type']}'] ??
            quantity;
        return ModelFuture.fromJson({
          ...row,
          'oi_net_qty_diff': quantity - old,
        });
      })
      .toList();
}

class _CountedRow extends MapBase<String, dynamic> {
  _CountedRow(this.data);
  final Map<String, dynamic> data;
  int quantityReads = 0;
  @override
  dynamic operator [](Object? key) {
    if (key == 'oi_net_qty') quantityReads++;
    return data[key];
  }

  @override
  Iterable<String> get keys => throw StateError('row should not be copied');
  @override
  void operator []=(String key, dynamic value) =>
      throw UnsupportedError('read-only');
  @override
  dynamic remove(Object? key) => throw UnsupportedError('read-only');
  @override
  void clear() => throw UnsupportedError('read-only');
}

class _CountedInstitutional extends ModelInstitutional {
  _CountedInstitutional(int value)
    : super(
        stockNo: '$value',
        stockName: '',
        foreignDiff: value,
        totalDiff: value,
      );
  int reads = 0;
  @override
  int get foreignDiff {
    reads++;
    return super.foreignDiff;
  }
}

void main() {
  test(
    'futures thresholds include exact magnitude and exact change boundaries',
    () {
      final rows = ModelStockFutures.project(
        current: [
          _row('臺股期貨', 'a', 199),
          _row('臺股期貨', 'b', 200),
          _row('臺股期貨', 'c', -200),
          _row('臺股期貨', 'd', 0),
        ],
        previous: [_row('臺股期貨', 'd', 200)],
      );
      expect(rows.map((row) => row.identityType), ['b', 'c', 'd']);
      expect(rows.map((row) => row.oiNetQtyDiff), [0, 0, -200]);
    },
  );

  test('futures quantities are parsed once without copying source maps', () {
    final current = _CountedRow(_row('臺股期貨', 'foreign', '500'));
    final previous = _CountedRow(_row('臺股期貨', 'foreign', '100'));
    final result = ModelStockFutures.project(
      current: [current],
      previous: [previous],
    );
    expect(result.single.oiNetQtyDiff, 400);
    expect(current.quantityReads, 1);
    expect(previous.quantityReads, 1);
    expect(current.data['oi_net_qty'], '500');
  });

  test(
    'unknown products cannot collide with a valid product/identity pair',
    () {
      final rows = ModelStockFutures.project(
        current: [_row('臺股期貨', 'x_foreign', 500)],
        previous: [_row('臺股期貨_x', 'foreign', -1000)],
      );
      expect(rows.single.oiNetQtyDiff, 0);
    },
  );

  test(
    'last history duplicate wins, missing history is not a false change',
    () {
      final rows = ModelStockFutures.project(
        current: [_row('臺股期貨', 'a', 500), _row('臺股期貨', null, -500)],
        previous: [_row('臺股期貨', 'a', 100), _row('臺股期貨', 'a', 300)],
      );
      expect(rows.map((row) => row.oiNetQtyDiff), [200, 0]);
    },
  );

  test(
    'futures randomized integer inputs preserve legacy output and order',
    () {
      final random = Random(28102);
      final products = <String?>[
        ...ModelStockFutures.productOrder.keys,
        'other',
        null,
      ];
      final identities = <String?>['foreign', 'dealer', 'trust', null];
      Map<String, dynamic> generate() => _row(
        products[random.nextInt(products.length)],
        identities[random.nextInt(identities.length)],
        random.nextInt(7) == 0 ? null : random.nextInt(2001) - 1000,
      );
      for (var batch = 0; batch < 100; batch++) {
        final current = List.generate(100, (_) => generate());
        final previous = List.generate(40, (_) => generate());
        expect(
          ModelStockFutures.project(
            current: current,
            previous: previous,
          ).map(_fields).toList(),
          _legacy(current, previous).map(_fields).toList(),
          reason: 'batch $batch',
        );
      }
    },
  );

  test(
    'futures ordering has exactly eight supported products and identity ties',
    () {
      expect(ModelStockFutures.productOrder, hasLength(8));
      final rows = [
        _row('電子期貨', 'a', 1),
        _row('臺股期貨', 'b', 1),
        _row('臺股期貨', 'a', 1),
        _row('other', 'a', 1),
      ]..sort(ModelStockFutures.compareRows);
      expect(
        rows.map((row) => '${row['product_name']}:${row['identity_type']}'),
        ['臺股期貨:a', '臺股期貨:b', '電子期貨:a', 'other:a'],
      );
    },
  );

  test('ranking reads each quantity once even while sorting many rows', () {
    final rows = List.generate(10000, (i) => _CountedInstitutional(i - 5000));
    final ranking = ModelStockInstitutionalRankings(rows);
    expect(rows.every((row) => row.reads == 1), isTrue);
    expect(ranking.buy.length, 4999);
    expect(ranking.sell.length, 5000);
    expect(rows.first.stockNo, '-5000');
    expect(ranking.buy.first.stockNo, '4999');
    expect(ranking.sell.first.stockNo, '-5000');
  });

  for (final quantities in [
    [100, -100, 90, -90, 0, 80, -80],
    [100, 90, -10, -100, 0],
    [100, 100, -10, -10, 0],
  ]) {
    test('ranking preserves legacy partition order for $quantities', () {
      final source = [
        for (var i = 0; i < quantities.length; i++)
          ModelInstitutional(
            stockNo: '$i',
            stockName: '',
            foreignDiff: quantities[i],
            totalDiff: 0,
          ),
      ];
      final expectedBuy = source.where((r) => r.foreignDiff > 0).toList()
        ..sort((a, b) => b.foreignDiff.compareTo(a.foreignDiff));
      final expectedSell = source.where((r) => r.foreignDiff < 0).toList()
        ..sort((a, b) => a.foreignDiff.compareTo(b.foreignDiff));
      final ranking = ModelStockInstitutionalRankings(source);
      expect(ranking.buy, orderedEquals(expectedBuy));
      expect(ranking.sell, orderedEquals(expectedSell));
      expect(source.map((r) => r.foreignDiff), quantities);
    });
  }

  test(
    'ranking matches legacy directions and tie order across randomized input',
    () {
      final random = Random(1028);
      for (var batch = 0; batch < 100; batch++) {
        final rows = List.generate(
          100,
          (i) => ModelInstitutional(
            stockNo: '$i',
            stockName: '',
            foreignDiff: random.nextInt(21) - 10,
            totalDiff: 0,
          ),
        );
        final buy = rows.where((row) => row.foreignDiff > 0).toList()
          ..sort((a, b) => b.foreignDiff.compareTo(a.foreignDiff));
        final sell = rows.where((row) => row.foreignDiff < 0).toList()
          ..sort((a, b) => a.foreignDiff.compareTo(b.foreignDiff));
        final ranking = ModelStockInstitutionalRankings(rows);
        expect(ranking.buy, buy);
        expect(ranking.sell, sell);
        expect(rows.map((row) => row.stockNo), List.generate(100, (i) => '$i'));
      }
    },
  );

  test(
    'new projections observe changed records rather than retaining old keys',
    () {
      final row = ModelInstitutional(
        stockNo: 'a',
        stockName: '',
        foreignDiff: 10,
        totalDiff: 10,
      );
      expect(ModelStockInstitutionalRankings([row]).buy, [row]);
      row.foreignDiff = -20;
      final updated = ModelStockInstitutionalRankings([row]);
      expect(updated.buy, isEmpty);
      expect(updated.sell, [row]);
      expect(ModelStockInstitutionalRankings([]).buy, isEmpty);
      expect(ModelStockFutures.project(current: [], previous: []), isEmpty);
    },
  );
}
