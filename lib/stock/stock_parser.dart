import 'package:life_pilot/stock/model_stock.dart';
import 'package:life_pilot/utils/logger.dart';
import 'package:life_pilot/utils/value_parser.dart';

class StockParser {
  static ModelStock? parse(
    List row,
    Map<String, int> enToIndex,
    DateTime date,
    bool isOTC,
    String source,
  ) {
    try {
      final cells = _StockRow(row, enToIndex);
      final securityCode = cells.text('security_code');
      final closingPrice = tryParseDoubleValue(
        cells.numberText('closing_price'),
      );

      if (securityCode.length != 4 || closingPrice == null) return null;
      final priceDifference =
          tryParseDoubleValue(cells.numberText('price_difference')) ?? 0;
      return ModelStock(
        date: date,
        securityCode: securityCode,
        securityName: cells.text('security_name'),
        tradedNumber: tryParseDoubleValue(cells.numberText('traded_number')),
        transactionsNumber: tryParseIntValue(
          cells.numberText('transactions_number'),
        ),
        transactionAmount: tryParseDoubleValue(
          cells.numberText('transaction_amount'),
        ),
        openingPrice: tryParseDoubleValue(cells.numberText('opening_price')),
        highestPrice: tryParseDoubleValue(cells.numberText('highest_price')),
        lowestPrice: tryParseDoubleValue(cells.numberText('lowest_price')),
        closingPrice: closingPrice,
        change: isOTC
            ? (priceDifference > 0 ? "+" : "-")
            : (cells.text('change').contains("+") ? "+" : "-"),
        priceDifference: priceDifference > 0
            ? priceDifference
            : priceDifference * (-1),
        finalRevealBuyingPrice: tryParseDoubleValue(
          cells.numberText('final_reveal_buying_price'),
        ),
        finalRevealBuyingVolume: tryParseDoubleValue(
          cells.numberText('final_reveal_buying_volume'),
        ),
        finalRevealSellingPrice: tryParseDoubleValue(
          cells.numberText('final_reveal_selling_price'),
        ),
        finalRevealSellingVolume: tryParseDoubleValue(
          cells.numberText('final_reveal_selling_volume'),
        ),
        peRatio: isOTC
            ? null
            : tryParseDoubleValue(cells.numberText('pe_ratio')),
        source: source,
      );
    } catch (e) {
      return null;
    }
  }

  static Map<String, dynamic>? parseT86(
    List row,
    Map<String, int> enToIndex,
    DateTime date,
    String source,
  ) {
    try {
      final cells = _StockRow(row, enToIndex);
      String get(String key) => cells.numberText(key, fallback: '0');

      return {
        "date": date.toUtc().toIso8601String(),
        "stock_no": cells.requiredValue("stock_no"),
        "stock_name": cells.requiredValue("stock_name"),
        "foreign_buy": parseIntValue(get("foreign_buy")),
        "foreign_sell": parseIntValue(get("foreign_sell")),
        "foreign_diff": parseIntValue(get("foreign_diff")),
        "foreign_dealer_buy": parseIntValue(get("foreign_dealer_buy")),
        "foreign_dealer_sell": parseIntValue(get("foreign_dealer_sell")),
        "foreign_dealer_diff": parseIntValue(get("foreign_dealer_diff")),
        "trust_buy": parseIntValue(get("trust_buy")),
        "trust_sell": parseIntValue(get("trust_sell")),
        "trust_diff": parseIntValue(get("trust_diff")),
        "dealer_diff": parseIntValue(get("dealer_diff")),
        "dealer_self_buy": parseIntValue(get("dealer_self_buy")),
        "dealer_self_sell": parseIntValue(get("dealer_self_sell")),
        "dealer_self_diff": parseIntValue(get("dealer_self_diff")),
        "dealer_hedge_buy": parseIntValue(get("dealer_hedge_buy")),
        "dealer_hedge_sell": parseIntValue(get("dealer_hedge_sell")),
        "dealer_hedge_diff": parseIntValue(get("dealer_hedge_diff")),
        "total_diff": parseIntValue(get("total_diff")),
        "source": source,
      };
    } catch (e) {
      logger.e('Invalid institutional stock row', error: e);
      return null;
    }
  }
}

/// Reads source columns without repeating index and numeric cleanup rules.
class _StockRow {
  const _StockRow(this.values, this.columns);

  final List<dynamic> values;
  final Map<String, int> columns;

  Object? requiredValue(String key) {
    final index = columns[key];
    if (index == null || index < 0 || index >= values.length) {
      throw FormatException('Missing stock column: $key');
    }
    return values[index];
  }

  String text(String key) => parseStringValue(requiredValue(key));

  String numberText(String key, {String? fallback}) {
    if (!columns.containsKey(key) && fallback != null) return fallback;
    return text(key).trim().replaceAll(',', '');
  }
}
