import 'package:life_pilot/stock/model_stock.dart';

/// Fresh ranking projection. Read each quantity once, partition in one pass,
/// and never sort the source list or cache mutable institutional records.
class ModelStockInstitutionalRankings {
  final List<ModelInstitutional> buy;
  final List<ModelInstitutional> sell;
  ModelStockInstitutionalRankings._(this.buy, this.sell);

  factory ModelStockInstitutionalRankings(Iterable<ModelInstitutional> source) {
    final buying = <({ModelInstitutional row, int quantity})>[];
    final selling = <({ModelInstitutional row, int quantity})>[];
    for (final row in source) {
      final quantity = row.foreignDiff;
      if (quantity > 0) buying.add((row: row, quantity: quantity));
      if (quantity < 0) selling.add((row: row, quantity: quantity));
    }
    buying.sort((left, right) => right.quantity.compareTo(left.quantity));
    selling.sort((left, right) => left.quantity.compareTo(right.quantity));
    return ModelStockInstitutionalRankings._(
      [for (final item in buying) item.row],
      [for (final item in selling) item.row],
    );
  }
}
