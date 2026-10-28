import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/stock/model_stock.dart';
import 'package:life_pilot/stock/model_stock_strategy.dart';
import 'package:life_pilot/stock/service_stock.dart' as compatibility;

ModelStock _stock(String id) => ModelStock(
  date: DateTime(2026, 10, 28),
  securityCode: id,
  securityName: id,
  closingPrice: 20,
  pctChange: 2,
  tradedNumber: 35000000,
  high20: 20,
  vol5: 10000000,
  ma5: 20,
  ma20: 20,
  rsi: 50,
);

class _CountingStock extends ModelStock {
  _CountingStock(String id, double percent)
    : super(
        date: DateTime(2026),
        securityCode: id,
        securityName: id,
        closingPrice: 100,
        pctChange: percent,
      );
  int percentReads = 0;
  int closeReads = 0;
  int ma5Reads = 0;
  @override
  double get closingPrice {
    closeReads++;
    return super.closingPrice;
  }

  @override
  double? get ma5 {
    ma5Reads++;
    return super.ma5;
  }

  @override
  double? get pctChange {
    percentReads++;
    return super.pctChange;
  }
}

List<ModelStock> _legacyRising(List<ModelStock> stocks) => stocks.where((s) {
  final close = s.closingPrice, high20 = s.high20 ?? 0;
  final vol5 = s.vol5 ?? 0, volume = s.tradedNumber ?? 0;
  final pct = s.pctChange ?? 0, ma5 = s.ma5 ?? 0;
  final ma20 = s.ma20 ?? 0, rsi = s.rsi ?? 0;
  final rising =
      close >= high20 &&
      volume >= vol5 * 1.5 &&
      pct >= 2 &&
      ma5 >= ma20 &&
      rsi >= 50 &&
      s.closingPrice >= 20 &&
      s.tradedNumber != null &&
      s.tradedNumber! >= 35000000;
  if (rising) s.isRising = true;
  return rising;
}).toList()..sort((a, b) => (b.pctChange ?? 0).compareTo(a.pctChange ?? 0));

double _legacyScore(ModelStock s) {
  double score = 0;
  score += (s.pctChange ?? 0) * 2;
  score += (s.ma5 ?? 0) / s.closingPrice * 2;
  score += (s.ma20 ?? 0) / s.closingPrice * 1.5;
  if (s.vol5 != null && s.vol5! > 0) {
    score += (s.tradedNumber! / s.vol5!) * 5;
  }
  if (s.high20 != null && s.high20! > 0) {
    score += (s.closingPrice / s.high20!) * 20;
  }
  if (s.rsi != null) score += s.rsi! * 0.3;
  if (s.highestPrice != null && s.lowestPrice != null) {
    final range = s.highestPrice! - s.lowestPrice!;
    if (range > 0) {
      final strength = (s.closingPrice - s.lowestPrice!) / range;
      score += strength * 10;
    }
  }
  if (s.ma5 != null && s.ma20 != null && s.ma5! > s.ma20!) score += 10;
  return score;
}

void main() {
  test('scoring values and arithmetic order match the previous formula', () {
    final random = Random(281028);
    for (var i = 0; i < 2000; i++) {
      double? optional() =>
          random.nextBool() ? random.nextDouble() * 200 : null;
      final stock = _stock('$i')
        ..closingPrice = i % 10 == 0 ? 0 : random.nextDouble() * 200
        ..pctChange = optional()
        ..ma5 = optional()
        ..ma20 = optional()
        ..vol5 = optional()
        ..high20 = optional()
        ..rsi = optional()
        ..highestPrice = optional()
        ..lowestPrice = optional();
      final expected = _legacyScore(stock);
      final actual = SimpleStrategy.score(stock);
      if (expected.isNaN) {
        expect(actual.isNaN, isTrue, reason: 'row $i');
      } else {
        expect(actual, expected, reason: 'row $i');
      }
    }
  });

  test('scoring formula and service import compatibility are unchanged', () {
    final stock = _stock('all')
      ..closingPrice = 100
      ..pctChange = 3
      ..ma5 = 110
      ..ma20 = 90
      ..vol5 = 100
      ..tradedNumber = 200
      ..high20 = 100
      ..rsi = 50
      ..highestPrice = 110
      ..lowestPrice = 90;
    expect(SimpleStrategy.score(stock), closeTo(69.55, 0.000000001));
    expect(
      compatibility.SimpleStrategy.score(stock),
      SimpleStrategy.score(stock),
    );
  });

  test('ranking evaluates each stock score once, not per comparison', () {
    final stocks = List.generate(
      10000,
      (i) => _CountingStock('$i', (i % 97).toDouble()),
    );
    final result = ModelStockStrategy.rankInPlace(stocks);
    expect(result, same(stocks));
    expect(stocks.every((stock) => stock.percentReads == 1), isTrue);
    expect(stocks.every((stock) => stock.closeReads == 1), isTrue);
    expect(stocks.every((stock) => stock.ma5Reads == 1), isTrue);
    expect(int.parse(stocks.first.securityCode) % 97, 96);
  });

  test('empty and single-row rankings need no score calculation', () {
    final empty = <ModelStock>[];
    expect(ModelStockStrategy.rankInPlace(empty), same(empty));
    final stock = _CountingStock('one', 1);
    final single = [stock];
    expect(ModelStockStrategy.rankInPlace(single), same(single));
    expect(stock.percentReads, 0);
  });

  test(
    'randomized rank order including ties matches repeated-score sorting',
    () {
      final random = Random(28103);
      for (var batch = 0; batch < 100; batch++) {
        final stocks = List.generate(
          100,
          (i) => _stock('$i')
            ..closingPrice = (1 + random.nextInt(10)).toDouble()
            ..pctChange = (random.nextInt(5) - 2).toDouble()
            ..ma5 = random.nextInt(5).toDouble()
            ..ma20 = random.nextInt(5).toDouble()
            ..tradedNumber = random.nextInt(5).toDouble()
            ..vol5 = 1
            ..high20 = 1
            ..rsi = random.nextInt(5).toDouble(),
        );
        final legacy = List<ModelStock>.of(stocks)
          ..sort(
            (a, b) =>
                SimpleStrategy.score(b).compareTo(SimpleStrategy.score(a)),
          );
        expect(
          ModelStockStrategy.rankInPlace(stocks),
          legacy,
          reason: 'batch $batch',
        );
      }
    },
  );

  test('zero-price and non-finite scoring keep the same comparison policy', () {
    final rows = [
      _stock('zero')..closingPrice = 0,
      _stock('positive'),
      _stock('infinite')..pctChange = double.infinity,
      _stock('nan')..pctChange = double.nan,
    ];
    final legacy = List<ModelStock>.of(rows)
      ..sort(
        (a, b) => SimpleStrategy.score(b).compareTo(SimpleStrategy.score(a)),
      );
    expect(ModelStockStrategy.rankInPlace(rows), legacy);
  });

  test('rising thresholds and existing marking behavior are preserved', () {
    final boundary = _stock('boundary');
    final lowVolume = _stock('low')
      ..tradedNumber = 34999999
      ..isRising = true;
    final absentVolume = _stock('missing')..tradedNumber = null;
    final rows = [boundary, lowVolume, absentVolume];
    expect(ModelStockStrategy.rising(rows), [boundary]);
    expect(boundary.isRising, isTrue);
    expect(lowVolume.isRising, isTrue); // Existing flags are not reset.
    expect(absentVolume.isRising, isNull);
    expect(rows, [boundary, lowVolume, absentVolume]);
  });

  test('rising randomized output and equal-percent tie order match legacy', () {
    final random = Random(28104);
    for (var batch = 0; batch < 100; batch++) {
      final rows = List.generate(
        100,
        (i) => _stock('$i')
          ..closingPrice = (18 + random.nextInt(8)).toDouble()
          ..pctChange = random.nextInt(5).toDouble()
          ..tradedNumber = random.nextBool() ? 35000000 : null
          ..high20 = random.nextBool() ? 20 : null
          ..vol5 = random.nextBool() ? 10000000 : null
          ..ma5 = random.nextBool() ? 20 : null
          ..ma20 = random.nextBool() ? 20 : null
          ..rsi = (48 + random.nextInt(5)).toDouble(),
      );
      final sourceOrder = List<ModelStock>.of(rows);
      final expected = _legacyRising(rows);
      expect(ModelStockStrategy.rising(rows), expected, reason: 'batch $batch');
      expect(rows, sourceOrder);
    }
  });

  test('changed mutable records are rescored on the next call', () {
    final a = _stock('a'), b = _stock('b')..pctChange = 10;
    final rows = [a, b];
    ModelStockStrategy.rankInPlace(rows);
    expect(rows.first, same(b));
    a.pctChange = 20;
    ModelStockStrategy.rankInPlace(rows);
    expect(rows.first, same(a));
    expect(compatibility.ServiceStock().filterRisingStocks(rows), [a, b]);
  });
}
