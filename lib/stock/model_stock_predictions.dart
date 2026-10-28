import 'package:life_pilot/stock/model_stock.dart';

/// Decode only: no querying, sorting, deduplication or retained snapshot state.
/// ModelStock reads fields without retaining or mutating the source map.
class ModelStockPredictions {
  static List<ModelStock> decode(
    Iterable<dynamic> rows, {
    required StockDataOrigin origin,
  }) => [
    for (final value in rows)
      ModelStock.fromJson(
        value is Map<String, dynamic>
            ? value
            : Map<String, dynamic>.from(value as Map),
      )..origin = origin,
  ];
}
