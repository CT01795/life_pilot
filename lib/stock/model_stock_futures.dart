import 'package:life_pilot/stock/model_stock.dart';
import 'package:life_pilot/utils/value_parser.dart';

/// Futures display policy only; no network, clock, localization or retained
/// user state. Product ordering and inclusion share a single definition.
class ModelStockFutures {
  static const productOrder = {
    '臺股期貨': 1,
    '小型臺指期貨': 2,
    '微型臺指期貨': 3,
    '金融期貨': 4,
    '小型金融期貨': 5,
    '電子期貨': 6,
    '小型電子期貨': 7,
    '非金電期貨': 8,
  };
  static const _minimumMagnitude = 200;

  static int compareRows(
    Map<String, dynamic> left,
    Map<String, dynamic> right,
  ) {
    final order = (productOrder[left['product_name']] ?? 999).compareTo(
      productOrder[right['product_name']] ?? 999,
    );
    if (order != 0) return order;
    return (left['identity_type'] as String? ?? '').compareTo(
      right['identity_type'] as String? ?? '',
    );
  }

  static List<ModelFuture> project({
    required Iterable<Map<String, dynamic>> current,
    required Iterable<Map<String, dynamic>> previous,
  }) {
    // Structured keys keep distinct product/identity combinations independent.
    final previousQuantities = <(Object?, Object?), num>{};
    for (final row in previous) {
      previousQuantities[(row['product_name'], row['identity_type'])] =
          parseNumValue(row['oi_net_qty']);
    }
    final result = <ModelFuture>[];
    for (final row in current) {
      final product = row['product_name'];
      if (!productOrder.containsKey(product)) continue;
      final identity = row['identity_type'];
      final parsedQuantity = tryParseNumValue(row['oi_net_qty']);
      final quantity = parsedQuantity ?? 0;
      final previousQuantity =
          previousQuantities[(product, identity)] ?? quantity;
      final change = quantity - previousQuantity;
      if (quantity.abs() < _minimumMagnitude &&
          change.abs() < _minimumMagnitude) {
        continue;
      }
      result.add(
        ModelFuture(
          productName: product as String,
          identityType: identity as String?,
          oiLongQty: tryParseIntValue(row['oi_long_qty']),
          oiShortQty: tryParseIntValue(row['oi_short_qty']),
          oiNetQty: parsedQuantity?.toInt(),
          oiNetQtyDiff: change.toInt(),
        ),
      );
    }
    return result;
  }
}
