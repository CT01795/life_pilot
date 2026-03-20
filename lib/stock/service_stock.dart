// lib/services/stock_service.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:life_pilot/stock/model_stock.dart';
import 'package:life_pilot/utils/const.dart';
import 'package:life_pilot/utils/logger.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ServiceStock {
  final client = Supabase.instance.client;
  List<ModelStock> stocks = [];
  int? stocksLength;
  Future<void> loadRawData() async {
    DateTime today = DateUtils.dateOnly(DateTime.now());
    int checkDates = 10;
    if (today.month < 3) {
      checkDates = 15;
    }
    for (int i = 1; i <= checkDates; i++) {
      await loadRawDataTWSE(
        today.subtract(Duration(days: i)),
      );
      await loadRawDataOTC(
        today.subtract(Duration(days: i)),
      );
    }
    for (int i = 1; i <= 300; i++) {
      await quantitativeCalculation(today.subtract(Duration(days: i)));
    }
   // await quantitativeCalculation(today.subtract(Duration(days: 1)));
  }

  Future<void> loadRawDataTWSE(DateTime date) async {
    String type = Source.twse;
    if (await isDataExist(date, type)) {
      return;
    }
    final dateStr =
        "${date.year}${date.month.toString().padLeft(2, '0')}${date.day.toString().padLeft(2, '0')}";
    final url =
        "https://www.twse.com.tw/exchangeReport/MI_INDEX?response=json&date=$dateStr&type=ALL";

    final response = await http.get(Uri.parse(url));

    if (response.statusCode != 200) {
      return;
    }
    try {
      final data = jsonDecode(response.body);
      final tables = data['tables'];

      if (tables == null) {
        return;
      }
      for (Map table in tables) {
        if (!(table["title"] ?? '').toString().contains("每日收盤行情")) {
          continue;
        }
        List<dynamic> fields = table["fields"];
        Map<String, String> chtToEn = {
          "證券代號": "security_code",
          "證券名稱": "security_name",
          "成交股數": "traded_number",
          "成交筆數": "transactions_number",
          "成交金額": "transaction_amount",
          "開盤價": "opening_price",
          "最高價": "highest_price",
          "最低價": "lowest_price",
          "收盤價": "closing_price",
          "漲跌(+/-)": "change",
          "漲跌價差": "price_difference",
          "最後揭示買價": "final_reveal_buying_price",
          "最後揭示買量": "final_reveal_buying_volume",
          "最後揭示賣價": "final_reveal_selling_price",
          "最後揭示賣量": "final_reveal_selling_volume",
          "本益比": "pe_ratio"
        };
        Map<String, int> enToIndex = {};
        for (int i = 0; i < fields.length; i++) {
          final key = chtToEn[fields[i]];
          if (key != null) enToIndex[key] = i;
        }
        List<dynamic> data = table["data"];
        List<Map<String, dynamic>> batch = [];
        for (int j = 0; j < data.length; j++) {
          final stock =
              StockParser.parse(data[j], enToIndex, date, false, type);
          if (stock == null) {
            continue;
          }
          batch.add(stock.toJson());
          if (batch.length >= 500) {
            await client.from(TableNames.stockDailyPrice).insert(batch);
            batch.clear();
          }
        }
        if (batch.isNotEmpty) {
          await client.from(TableNames.stockDailyPrice).insert(batch);
          batch.clear();
        }
        await client
            .from(TableNames.stockDate)
            .insert({"date": date.toIso8601String(), "type": type});
      }
    } on Exception catch (ex) {
      logger.e(ex);
    }
  }

  Future<void> loadRawDataOTC(DateTime date) async {
    String type = Source.tpex;
    if (await isDataExist(date, type)) {
      return;
    }
    final dateStr =
        "${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}";
    final url =
        "https://www.tpex.org.tw/www/zh-tw/afterTrading/otc?date=$dateStr&type=AL&id=&response=json";

    final response = await http.get(Uri.parse(url));

    if (response.statusCode != 200) {
      return;
    }
    try {
      final rawData = jsonDecode(response.body);
      final tables = rawData['tables'];

      if (tables == null) {
        return;
      }

      List<dynamic> fields = tables[0]["fields"];
      Map<String, String> chtToEn = {
        "代號": "security_code", //
        "名稱": "security_name", //
        "收盤": "closing_price", //
        "開盤": "opening_price", //
        "最高": "highest_price", //
        "最低": "lowest_price", //
        "成交股數": "traded_number", //
        "成交金額(元)": "transaction_amount", //
        "成交筆數": "transactions_number", //
        "最後買價": "final_reveal_buying_price", //
        "最後買量": "final_reveal_buying_volume", //
        "最後賣價": "final_reveal_selling_price", //
        "最後賣量": "final_reveal_selling_volume", //
        "漲跌(+/-)": "change",
        "漲跌": "price_difference", //
      };
      Map<String, int> enToIndex = {};
      for (int i = 0; i < fields.length; i++) {
        final key = chtToEn[fields[i].toString().trim().split("<")[0]];
        if (key != null) enToIndex[key] = i;
      }
      List<dynamic> data = tables[0]["data"];
      List<Map<String, dynamic>> batch = [];
      for (int j = 0; j < data.length; j++) {
        final stock = StockParser.parse(data[j], enToIndex, date, true, type);
        if (stock == null) {
          continue;
        }
        batch.add(stock.toJson());
        if (batch.length >= 500) {
          await client.from(TableNames.stockDailyPrice).insert(batch);
          batch.clear();
        }
      }
      if (batch.isNotEmpty) {
        await client.from(TableNames.stockDailyPrice).insert(batch);
        batch.clear();
      }
      await client
          .from(TableNames.stockDate)
          .insert({"date": date.toIso8601String(), "type": type});
    } on Exception catch (ex) {
      logger.e(ex);
    }
  }

  Future<bool> isDataExist(DateTime date, String type) async {
    final result = await client
        .from(TableNames.stockDate)
        .select('date')
        .eq('date', date)
        .eq('type', type)
        .limit(1);
    return result.isNotEmpty;
  }

  Future<void> insertStock(ModelStock stock) async {
    await client.from(TableNames.stockDailyPrice).insert(stock.toJson());
  }

  Future<List<ModelStock>> getByDate(DateTime date) async {
    final result = await client
        .from(TableNames.stockDailyPrice)
        .select('*')
        .eq('date', date)
        .gte('traded_number', 900000)
        .lt('closing_price', 1000);

    return result.map<ModelStock>((e) => ModelStock.fromJson(e)).toList();
  }

  Future<DateTime?> getLatestDate() async {
    final result = await client
        .from(TableNames.stockDailyPrice)
        .select('date')
        .order('date', ascending: false)
        .limit(1);

    if (result.isEmpty) return null;

    return DateTime.parse(result.first['date']);
  }

  Future<List<ModelStock>> getSimpleStrategy() async {
    // 1️⃣ 找最新日期
    final latestDate = await getLatestDate();
    if (latestDate == null) {
      return [];
    }

    // 2️⃣ 抓該日全部股票
    List<ModelStock> allStocks = await getByDate(latestDate);

    /*close > high20	今日收盤突破過去 20 日高點 → 剛起漲
      volume > vol5*1.5	成交量放大 → 市場有力道
      pct_change > 2	當日漲幅 >2% → 明顯起漲
      ma5 > ma20	均線多頭排列 → 趨勢向上*/
    List<ModelStock> risingStocks = filterRisingStocks(allStocks);

    // 👉 下一步：量化排序
    List<ModelStock> ranked = _rankStocks(allStocks);

    // 4️⃣ 合併（避免重複）
    final map = {
      for (var s in risingStocks) s.securityCode: s,
    };

    for (var s in ranked.take(200)) {
      map.putIfAbsent(s.securityCode, () => s);
    }

    stocks = map.values.toList();
    return stocks;
  }

  List<ModelStock> _rankStocks(List<ModelStock> list) {
    list.sort((a, b) {
      double scoreA = SimpleStrategy.score(a);
      double scoreB = SimpleStrategy.score(b);
      return scoreB.compareTo(scoreA); // 高分排前面
    });
    return list;
  }

  List<ModelStock> filterRisingStocks(List<ModelStock> stocks) {
    return stocks.where((s) {
      final close = s.closingPrice;
      final high20 = s.high20 ?? 0;
      final vol5 = s.vol5 ?? 0;
      final volume = s.tradedNumber ?? 0;
      final pct = s.pctChange ?? 0;
      final ma5 = s.ma5 ?? 0;
      final ma20 = s.ma20 ?? 0;
      final rsi = s.rsi ?? 0;

      final isRising = close >= high20 && // 1️⃣ 突破20日高點
          volume >= vol5 * 1.5 && // 2️⃣ 成交量放大
          pct > 2 && // 3️⃣ 漲幅 > 2%
          ma5 > ma20 && // 4️⃣ 均線多頭
          rsi > 50 &&
          rsi < 80; //排除假突破與過熱

      if (isRising) {
        s.isRising = true; // 👈 標記
      }
      return isRising;
    }).toList()
      ..sort((a, b) => (b.pctChange ?? 0).compareTo(a.pctChange ?? 0));
  }

  Future<void> quantitativeCalculation(DateTime date) async {
    /*ma5           → 5日均線
      ma20          → 20日均線
      high20        → 過去20日最高收盤價
      pctChange     → 當日漲幅 %
      vol5        → 最近5日平均成交量*/
    final result = await client
        .from('stock_daily_price')
        .select('*')
        .eq('date', date)
        .or('ma5.is.null,vol5.is.null')
        .count(); // ✅ 只返回 count，不取資料
    int batch = 150; //不可動batch數量!!!
    stocksLength = (result.count / batch).ceil();
    if (result.count == 0) {
      return;
    }
    for (int i = 0; i < stocksLength!; i++) {
      await client.rpc(
        'update_stock_technical_for_date',
        params: {
          'p_date': date.toIso8601String().substring(0, 10),
          'p_start': 1,
          'p_end': i < stocksLength! - 1 ? batch : result.count - batch * i,
        },
      );
    }
    await client.from(TableNames.stockDate).insert({
      "type": 'update_stock_technical_for_date',
      "date": date.toIso8601String().substring(0, 10)
    });
  }
}

class SimpleStrategy {
  static double score(ModelStock s) {
    double score = 0;

    //綜合考量：漲幅 成交量 本益比 動能
    // 1️⃣ 漲幅（最重要）
    score += ((s.priceDifference ?? 0) *
            (s.change != null && s.change!.contains("+") ? 1 : -1) /
            s.closingPrice) *
        200;

    // 4️⃣ 價格動能（收盤接近最高）
    if (s.highestPrice != null && s.closingPrice > 0) {
      score += (s.closingPrice / s.highestPrice!) * 10;
    }

    // 2️⃣ 成交量（熱門股）
    score += (s.tradedNumber ?? 0) / 10000000; //10,000,000

    // 3️⃣ 本益比（越低越好）
    if (s.peRatio != null && s.peRatio! > 0) {
      score += (20 - s.peRatio!) * 0.5;
    }
    return score;
  }
}

class StockParser {
  static ModelStock? parse(List row, Map<String, int> enToIndex, DateTime date,
      bool isOTC, String source) {
    try {
      final securityCode = row[enToIndex["security_code"] ?? -1].toString();
      final closingPrice = double.tryParse(
          row[enToIndex["closing_price"] ?? -1].toString().replaceAll(',', ''));

      if (securityCode.length != 4 || closingPrice == null) return null;
      final priceDifference = double.tryParse(
              row[enToIndex["price_difference"] ?? -1]
                  .toString()
                  .trim()
                  .replaceAll(',', '')) ??
          0;
      return ModelStock(
          date: date,
          securityCode: securityCode,
          securityName: row[enToIndex["security_name"] ?? -1].toString(),
          tradedNumber: double.tryParse(row[enToIndex["traded_number"] ?? -1]
              .toString()
              .replaceAll(',', '')),
          transactionsNumber: int.tryParse(
              row[enToIndex["transactions_number"] ?? -1]
                  .toString()
                  .replaceAll(',', '')),
          transactionAmount: double.tryParse(
              row[enToIndex["transaction_amount"] ?? -1]
                  .toString()
                  .replaceAll(',', '')),
          openingPrice: double.tryParse(row[enToIndex["opening_price"] ?? -1]
              .toString()
              .replaceAll(',', '')),
          highestPrice: double.tryParse(
              row[enToIndex["highest_price"] ?? -1].toString().replaceAll(',', '')),
          lowestPrice: double.tryParse(row[enToIndex["lowest_price"] ?? -1].toString().replaceAll(',', '')),
          closingPrice: closingPrice,
          change: isOTC ? (priceDifference > 0 ? "+" : "-") : (row[enToIndex["change"] ?? -1].toString().contains("+") ? "+" : "-"),
          priceDifference: priceDifference > 0 ? priceDifference : priceDifference * (-1),
          finalRevealBuyingPrice: double.tryParse(row[enToIndex["final_reveal_buying_price"] ?? -1].toString().replaceAll(',', '')),
          finalRevealBuyingVolume: double.tryParse(row[enToIndex["final_reveal_buying_volume"] ?? -1].toString().replaceAll(',', '')),
          finalRevealSellingPrice: double.tryParse(row[enToIndex["final_reveal_selling_price"] ?? -1].toString().replaceAll(',', '')),
          finalRevealSellingVolume: double.tryParse(row[enToIndex["final_reveal_selling_volume"] ?? -1].toString().replaceAll(',', '')),
          peRatio: isOTC ? null : double.tryParse(row[enToIndex["pe_ratio"] ?? -1].toString().replaceAll(',', '')),
          source: source);
    } catch (e) {
      return null;
    }
  }
}
