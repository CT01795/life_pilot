import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/record_statistics/model_record_explorer_metrics.dart';

void main() {
  test('empty and zero-only rows have no positive or negative movement', () {
    for (final rows in <List<num>>[
      [],
      [0, -0.0],
    ]) {
      final model = ModelRecordExplorerMetrics.from(
        rows,
        valueOf: (value) => value,
      );
      expect([model.positive, model.negativeMagnitude, model.net], [0, 0, 0]);
    }
  });
  test('signed four-decimal values retain source addition precision', () {
    final values = <num>[12.3456, -2.1234, 0.0001, -0.0002];
    final model = ModelRecordExplorerMetrics.from(
      values,
      valueOf: (value) => value,
    );
    expect(model.positive, 12.3456 + 0.0001);
    expect(model.negativeMagnitude, 2.1234 + 0.0002);
    expect(model.net, (12.3456 + 0.0001) - (2.1234 + 0.0002));
  });
  test('point integer inputs keep integer sums and a negative net', () {
    final model = ModelRecordExplorerMetrics.from([
      4,
      -9,
      3,
      -2,
    ], valueOf: (value) => value);
    expect([model.positive, model.negativeMagnitude, model.net], [7, 11, -4]);
    expect(model.positive, isA<int>());
    expect(model.negativeMagnitude, isA<int>());
    expect(model.net, isA<int>());
  });
  test(
    'include filters before value reads, without changing exact currency policy',
    () {
      final records = <({String currency, num value})>[
        (currency: 'TWD', value: 5),
        (currency: 'twd', value: 999),
        (currency: 'USD', value: -999),
        (currency: 'TWD', value: -2),
      ];
      var valueReads = 0;
      final model = ModelRecordExplorerMetrics.from(
        records,
        include: (row) => row.currency == 'TWD',
        valueOf: (row) {
          valueReads++;
          return row.value;
        },
      );
      expect([model.positive, model.negativeMagnitude, model.net], [5, 2, 3]);
      expect(valueReads, 2);
    },
  );
  test('reads one-shot iterable and each included value only once', () {
    var visits = 0;
    var reads = 0;
    Iterable<int> source() sync* {
      for (var i = -500; i < 500; i++) {
        visits++;
        yield i;
      }
    }

    final model = ModelRecordExplorerMetrics.from(
      source(),
      valueOf: (value) {
        reads++;
        return value;
      },
    );
    expect(visits, 1000);
    expect(reads, 1000);
    expect(model.net, -500);
    expect(model.net, -500);
    expect(visits, 1000);
  });
  test('randomized results exactly match previous separate folds', () {
    final random = Random(91);
    for (var batch = 0; batch < 300; batch++) {
      final values = List<num>.generate(
        200,
        (_) => (random.nextInt(200000) - 100000) / 10000,
      );
      final positive = values
          .where((value) => value > 0)
          .fold<num>(0, (sum, value) => sum + value);
      final negative = values
          .where((value) => value < 0)
          .fold<num>(0, (sum, value) => sum + value.abs());
      final model = ModelRecordExplorerMetrics.from(
        values,
        valueOf: (value) => value,
      );
      expect(
        [model.positive, model.negativeMagnitude, model.net],
        [positive, negative, positive - negative],
      );
    }
  });
  test(
    'source order and contents remain untouched and no stale projection is reused',
    () {
      final source = <num>[8, -2, 1];
      final old = ModelRecordExplorerMetrics.from(
        List<num>.unmodifiable(source),
        valueOf: (value) => value,
      );
      expect(source, [8, -2, 1]);
      source[0] = 20;
      final fresh = ModelRecordExplorerMetrics.from(
        source,
        valueOf: (value) => value,
      );
      expect(old.net, 7);
      expect(fresh.net, 19);
    },
  );
  test('NaN values remain excluded just as in the original sign filters', () {
    final model = ModelRecordExplorerMetrics.from(<num>[
      double.nan,
      3,
      -1,
    ], valueOf: (value) => value);
    expect([model.positive, model.negativeMagnitude, model.net], [3, 1, 2]);
  });
}
