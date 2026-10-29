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
    var buyingOrdered = true, sellingOrdered = true;
    for (final row in source) {
      final quantity = row.foreignDiff;
      if (quantity > 0) {
        if (buyingOrdered &&
            buying.isNotEmpty &&
            buying.last.quantity <= quantity) {
          buyingOrdered = false;
        }
        buying.add((row: row, quantity: quantity));
      }
      if (quantity < 0) {
        if (sellingOrdered &&
            selling.isNotEmpty &&
            selling.last.quantity >= quantity) {
          sellingOrdered = false;
        }
        selling.add((row: row, quantity: quantity));
      }
    }
    // Strict order only: ties must keep the legacy sort/tie behavior.
    if (!buyingOrdered) {
      buying.sort((left, right) => right.quantity.compareTo(left.quantity));
    }
    if (!sellingOrdered) {
      selling.sort((left, right) => left.quantity.compareTo(right.quantity));
    }
    return ModelStockInstitutionalRankings._(
      [for (final item in buying) item.row],
      [for (final item in selling) item.row],
    );
  }
}
