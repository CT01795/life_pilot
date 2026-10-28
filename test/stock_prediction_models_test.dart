import 'dart:collection';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/stock/model_stock.dart';
import 'package:life_pilot/stock/model_stock_predictions.dart';

Map<String, dynamic> _row(String code, String name) => {
  'date': '2026-10-28T00:00:00Z',
  'security_code': code,
  'security_name': name,
  'closing_price': '1234.5',
  'traded_number': '100000',
  'pred_pct': '2.34',
  'signal': '1',
  'signal_text': 'test',
};

class _ReadOnlyRow extends MapBase<String, dynamic> {
  _ReadOnlyRow(this.source);
  final Map<String, dynamic> source;
  @override
  dynamic operator [](Object? key) => source[key];
  @override
  Iterable<String> get keys => throw StateError('Unnecessary source map copy');
  @override
  void operator []=(String key, dynamic value) =>
      throw UnsupportedError('read-only');
  @override
  dynamic remove(Object? key) => throw UnsupportedError('read-only');
  @override
  void clear() => throw UnsupportedError('read-only');
}

class _SinglePass extends Iterable<dynamic> {
  _SinglePass(this.rows);
  final List<dynamic> rows;
  int iterations = 0;
  @override
  Iterator<dynamic> get iterator {
    if (++iterations > 1) throw StateError('Repeated traversal');
    return rows.iterator;
  }
}

void main() {
  test('backend predictions reuse decoding without copying typed maps', () {
    final raw = _row('2330', 'Backend stock');
    final source = List.generate(10000, (_) => _ReadOnlyRow(raw));
    final rows = ModelStockPredictions.decode(
      _SinglePass(source),
      origin: StockDataOrigin.backend,
    );
    expect(rows, hasLength(10000));
    expect(rows.every((row) => row.origin == StockDataOrigin.backend), isTrue);
    expect(rows.first.toJsonPred(), ModelStock.fromJson(raw).toJsonPred());
    expect(rows.first.securityName, 'Backend stock');
    expect(raw['security_name'], 'Backend stock');
    expect(identical(rows.first, rows.last), isFalse);
  });

  test('typed maps decode without copying, enumeration or source mutation', () {
    final raw = _row('2330', 'Stock');
    final rows = ModelStockPredictions.decode([
      _ReadOnlyRow(raw),
    ], origin: StockDataOrigin.cloud);
    expect(rows.single.securityCode, '2330');
    expect(rows.single.closingPrice, 1234.5);
    expect(rows.single.origin, StockDataOrigin.cloud);
    expect(raw.containsKey('origin'), isFalse);
    expect(raw['closing_price'], '1234.5');
  });

  test('legacy untyped maps keep the existing conversion behavior', () {
    final row = Map<dynamic, dynamic>.from(_row('2330', 'Stock'));
    final actual = ModelStockPredictions.decode([
      row,
    ], origin: StockDataOrigin.cloud).single;
    final expected = ModelStock.fromJson(Map<String, dynamic>.from(row));
    expect(actual.toJsonPred(), expected.toJsonPred());
    expect(actual.signal, expected.signal);
    expect(actual.signalText, expected.signalText);
  });

  test('decoding preserves duplicate IDs, order and unmodified names', () {
    final rows = ModelStockPredictions.decode([
      _row('2330', 'first'),
      _row('2330', 'duplicate'),
      _row('2317', 'last'),
    ], origin: StockDataOrigin.cloud);
    expect(rows.map((row) => row.securityName), ['first', 'duplicate', 'last']);
    expect(rows.every((row) => row.level == null), isTrue);
  });

  test(
    'each decode observes new data rather than retaining source identities',
    () {
      final row = _row('2330', 'before');
      final first = ModelStockPredictions.decode([
        row,
      ], origin: StockDataOrigin.cloud).single;
      row['security_name'] = 'after';
      row['closing_price'] = 2000;
      final second = ModelStockPredictions.decode([
        row,
      ], origin: StockDataOrigin.cloud).single;
      expect(first.securityName, 'before');
      expect(first.closingPrice, 1234.5);
      expect(second.securityName, 'after');
      expect(second.closingPrice, 2000);
      expect(second, isNot(same(first)));
    },
  );

  test('large snapshots are traversed once and return an independent list', () {
    final source = _SinglePass(
      List.generate(10000, (i) => _ReadOnlyRow(_row('$i', '$i'))),
    );
    final rows = ModelStockPredictions.decode(
      source,
      origin: StockDataOrigin.cloud,
    );
    expect(rows, hasLength(10000));
    expect(source.iterations, 1);
    rows.clear();
    expect(source.rows, hasLength(10000));
  });

  test('invalid entries fail rather than silently returning partial data', () {
    expect(
      () => ModelStockPredictions.decode([
        _row('2330', 'valid'),
        'invalid',
      ], origin: StockDataOrigin.cloud),
      throwsA(isA<TypeError>()),
    );
    expect(
      ModelStockPredictions.decode([], origin: StockDataOrigin.cloud),
      isEmpty,
    );
  });
}
