// lib/services/stock_service.dart
import 'dart:convert';
import 'package:csv/csv.dart';
import 'package:http/http.dart' as http;
import 'package:life_pilot/stock/model_stock.dart';
import 'package:life_pilot/utils/const.dart';
import 'package:life_pilot/utils/logger.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ServiceStock {
  final client = Supabase.instance.client;
  List<ModelStock> stocks = [];
  Future<void> loadRawDataDailyPrices(DateTime date) async {
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
          final stock = StockParser.parse(data[j], enToIndex, date, false, type);
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

  Future<void> fetchOtcCsv(DateTime date) async {
    String type = Source.tpex;
    if (await isDataExist(date, type)) {
      return;
    }
    final dateStr =
        "${date.year}${date.month.toString().padLeft(2, '0')}${date.day.toString().padLeft(2, '0')}";
    final url =
        "https://www.tpex.org.tw/web/stock/aftertrading/DAILY_CLOSE_quotes/stk_quote_result.php"
        "?l=zh-tw&o=data&d=$dateStr";

    final response = await http.get(Uri.parse(url));

    if (response.statusCode != 200) {
      return;
    }

    try {
      final csvString = utf8.decode(response.bodyBytes);
      final data = const CsvToListConverter().convert(csvString);

      if (data.isEmpty || data.length <= 1) {
        return;
      }

      List<dynamic> fields = data[0];
      Map<String, String> chtToEn = {
        "代號": "security_code", //
        "名稱": "security_name", //
        "收盤": "closing_price", //
        "開盤": "opening_price", //
        "最高": "highest_price", //
        "最低": "lowest_price", //
        "成交股數": "traded_number", //
        "成交金額": "transaction_amount", //
        "成交筆數": "transactions_number", //
        "最後買價": "final_reveal_buying_price", //
        "最後賣價": "final_reveal_selling_price", //
        "漲跌(+/-)": "change",
        "漲跌": "price_difference", //
      };
      Map<String, int> enToIndex = {};
      for (int i = 0; i < fields.length; i++) {
        final key = chtToEn[fields[i]];
        if (key != null) enToIndex[key] = i;
      }

      List<Map<String, dynamic>> batch = [];
      for (int j = 1; j < data.length; j++) {
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

  Future<List<ModelStock>> getStatData() async {
    // 1️⃣ 找最新日期
    final latestDate = await getLatestDate();
    if (latestDate == null) {
      return [];
    }

    // 2️⃣ 抓該日全部股票
    List<ModelStock> allStocks = await getByDate(latestDate);

    // 👉 下一步：量化排序
    stocks = _rankStocks(allStocks);

    return stocks.take(50).toList();
  }

  List<ModelStock> _rankStocks(List<ModelStock> list) {
    list.sort((a, b) {
      double scoreA = SimpleStrategy.score(a);
      double scoreB = SimpleStrategy.score(b);
      return scoreB.compareTo(scoreA); // 高分排前面
    });
    return list;
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
  static ModelStock? parse(
      List row, Map<String, int> enToIndex, DateTime date, bool isOTC, String source) {
    try {
      final securityCode = row[enToIndex["security_code"] ?? -1].toString();
      final closingPrice = double.tryParse(
          row[enToIndex["closing_price"] ?? -1].toString().replaceAll(',', ''));

      if (securityCode.length != 4 || closingPrice == null) return null;
      final priceDifference = double.tryParse(
              row[enToIndex["price_difference"] ?? -1]
                  .toString().trim()
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
          finalRevealBuyingVolume: isOTC ? null : double.tryParse(row[enToIndex["final_reveal_buying_volume"] ?? -1].toString().replaceAll(',', '')),
          finalRevealSellingPrice: double.tryParse(row[enToIndex["final_reveal_selling_price"] ?? -1].toString().replaceAll(',', '')),
          finalRevealSellingVolume: isOTC ? null : double.tryParse(row[enToIndex["final_reveal_selling_volume"] ?? -1].toString().replaceAll(',', '')),
          peRatio: isOTC ? null : double.tryParse(row[enToIndex["pe_ratio"] ?? -1].toString().replaceAll(',', '')),
          source: source);
    } catch (e) {
      return null;
    }
  }
}
