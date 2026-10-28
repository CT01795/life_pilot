import 'package:life_pilot/stock/model_stock.dart';

/// Strategy policy only. Keys belong to one call because stocks remain mutable.
class ModelStockStrategy {
  static List<ModelStock> rankInPlace(List<ModelStock> stocks) {
    if (stocks.length < 2) return stocks;
    final ranked = [
      for (final stock in stocks)
        (stock: stock, score: SimpleStrategy.score(stock)),
    ];
    ranked.sort((left, right) => right.score.compareTo(left.score));
    for (var i = 0; i < ranked.length; i++) {
      stocks[i] = ranked[i].stock;
    }
    return stocks;
  }

  static List<ModelStock> rising(List<ModelStock> stocks) {
    final selected = <({ModelStock stock, double percent})>[];
    for (final stock in stocks) {
      final close = stock.closingPrice;
      final high20 = stock.high20 ?? 0;
      final vol5 = stock.vol5 ?? 0;
      final volume = stock.tradedNumber ?? 0;
      final percent = stock.pctChange ?? 0;
      final ma5 = stock.ma5 ?? 0;
      final ma20 = stock.ma20 ?? 0;
      final rsi = stock.rsi ?? 0;
      if (close >= high20 &&
          volume >= vol5 * 1.5 &&
          percent >= 2 &&
          ma5 >= ma20 &&
          rsi >= 50 &&
          close >= 20 &&
          volume >= 35000000) {
        // Preserve the existing mark-matches-only contract.
        stock.isRising = true;
        selected.add((stock: stock, percent: percent));
      }
    }
    selected.sort((left, right) => right.percent.compareTo(left.percent));
    return [for (final entry in selected) entry.stock];
  }
}

/// Scoring policy only. Values are local to one evaluation, never cached on
/// mutable stock records. Keep arithmetic order and thresholds unchanged.
class SimpleStrategy {
  static double score(ModelStock s) {
    final close = s.closingPrice;
    final ma5 = s.ma5;
    final ma20 = s.ma20;
    final vol5 = s.vol5;
    final high20 = s.high20;
    final rsi = s.rsi;
    final high = s.highestPrice;
    final low = s.lowestPrice;
    double score = 0;

    //綜合考量：漲幅 成交量 本益比 動能
    // 1️⃣ 短中期動能（核心）
    score += (s.pctChange ?? 0) * 2;
    score += (ma5 ?? 0) / close * 2;
    score += (ma20 ?? 0) / close * 1.5;

    // 2️⃣ 量能爆發
    if (vol5 != null && vol5 > 0) {
      score += (s.tradedNumber! / vol5) * 5;
    }

    // 3️⃣ 突破強度
    if (high20 != null && high20 > 0) {
      score += (close / high20) * 20;
    }

    // 4️⃣ RSI 動能
    if (rsi != null) {
      score += rsi * 0.3;
    }

    // 5️⃣ K棒強度
    if (high != null && low != null) {
      double range = high - low;
      if (range > 0) {
        double strength = (close - low) / range;
        score += strength * 10;
      }
    }

    // 6️⃣ 均線結構
    if (ma5 != null && ma20 != null) {
      if (ma5 > ma20) {
        score += 10;
      }
    }
    return score;
  }
}
