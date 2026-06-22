// lib/services/stock_service.dart
import 'dart:convert';

import 'package:flutter/material.dart' hide Element;
import 'package:intl/intl.dart';
import 'package:life_pilot/stock/model_stock.dart';
import 'package:life_pilot/utils/api.dart';
import 'package:life_pilot/utils/const.dart';
import 'package:life_pilot/utils/logger.dart';

class ServiceStock {
  List<ModelStock> stocks = [];
  int? stocksLength;
  Future<void> loadRawData() async {
    DateTime today = DateUtils.dateOnly(DateTime.now()).add(Duration(hours: 8));
    final cutoffDate = today.subtract(Duration(days: 370));
    await api.post('stock/delete_stock_daily_price', {
      'table_name': TableNames.stockDailyPrice,
      'date': cutoffDate.toIso8601String(),
    });
    await api.post('stock/delete_stock_date', {
      'table_name': TableNames.stockDate,
      'date': cutoffDate.toIso8601String(),
    });
    int checkDates = 2;
    int minDayValue = 1;
    if (DateTime.now().hour >= 17) {
      minDayValue = 0;
    }
    for (int i = checkDates; i >= minDayValue; i--) {
      DateTime targetDate = today.subtract(Duration(days: i));
      await loadRawDataTWSE(targetDate);
      await loadRawDataOTC(targetDate);
      await loadStockInstitutionalTWSE(targetDate);
      await loadStockInstitutionalOTC(targetDate);
      await insertStockInstitutionalToSupabase(targetDate);
      await loadFuturesInstitutional(targetDate);
      await insertFuturesToSupabase(targetDate);
      await quantitativeCalculation(500, targetDate);
    }
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

    final response = await api.post('event/get_url_data', {
      'url': url,
      'method': 'GET',
    });
    if (response['status'] != 'ok') return;
    final data = jsonDecode(response["data"]);

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
          await api.post('stock/insert_stock_daily_price_batch', {
            'table_name': TableNames.stockDailyPrice,
            'stocks': batch,
          });
          batch.clear();
        }
      }
      if (batch.isNotEmpty) {
        await api.post('stock/insert_stock_daily_price_batch', {
          'table_name': TableNames.stockDailyPrice,
          'stocks': batch,
        });
        batch.clear();
      }

      await api.post('stock/insert_stock_date_batch', {
        'table_name': TableNames.stockDate,
        'stocks': [
          {
            'date': date.toUtc().toIso8601String(),
            'type': type,
          }
        ],
      });
    }
  }

  Future<void> loadStockInstitutionalTWSE(DateTime date) async {
    String type = Source.updateStockTechnicalForDate;
    if (await isDataExist(date, type)) {
      return;
    }
    final dateStr =
        "${date.year}${date.month.toString().padLeft(2, '0')}${date.day.toString().padLeft(2, '0')}";
    final url =
        "https://www.twse.com.tw/rwd/zh/fund/T86?date=$dateStr&selectType=ALL&response=json";

    final response = await api.post('event/get_url_data', {
      'url': url,
      'method': 'GET',
    });
    if (response['status'] != 'ok') return;
    Map dataSource = jsonDecode(response["data"]);
    if (dataSource["stat"]?.toString().toLowerCase() != 'ok') return;
    List<dynamic> fields = dataSource["fields"];

    Map<String, String> chtToEn = {
      "證券代號": "stock_no",
      "證券名稱": "stock_name",
      "外陸資買進股數(不含外資自營商)": "foreign_buy",
      "外陸資賣出股數(不含外資自營商)": "foreign_sell",
      "外陸資買賣超股數(不含外資自營商)": "foreign_diff",
      "外資自營商買進股數": "foreign_dealer_buy",
      "外資自營商賣出股數": "foreign_dealer_sell",
      "外資自營商買賣超股數": "foreign_dealer_diff",
      "投信買進股數": "trust_buy",
      "投信賣出股數": "trust_sell",
      "投信買賣超股數": "trust_diff",
      "自營商買賣超股數": "dealer_diff",
      "自營商買進股數(自行買賣)": "dealer_self_buy",
      "自營商賣出股數(自行買賣)": "dealer_self_sell",
      "自營商買賣超股數(自行買賣)": "dealer_self_diff",
      "自營商買進股數(避險)": "dealer_hedge_buy",
      "自營商賣出股數(避險)": "dealer_hedge_sell",
      "自營商買賣超股數(避險)": "dealer_hedge_diff",
      "三大法人買賣超股數": "total_diff",
    };
    Map<String, int> enToIndex = {};
    for (int i = 0; i < fields.length; i++) {
      final key = chtToEn[fields[i]];
      if (key != null) enToIndex[key] = i;
    }
    List<dynamic> data = dataSource["data"];
    List<Map<String, dynamic>> batch = [];
    for (int j = 0; j < data.length; j++) {
      final stockInstitutional =
          StockParser.parseT86(data[j], enToIndex, date, type);
      if (stockInstitutional == null) {
        continue;
      }
      batch.add(stockInstitutional);
      if (batch.length >= 500) {
        await api.post('stock/insert_stock_institutional_batch', {
          'table_name': TableNames.stockInstitutional,
          'stocks': batch,
        });
        batch.clear();
      }
    }
    if (batch.isNotEmpty) {
      await api.post('stock/insert_stock_institutional_batch', {
        'table_name': TableNames.stockInstitutional,
        'stocks': batch,
      });
      batch.clear();
    }
  }

  Future<void> loadStockInstitutionalOTC(DateTime date) async {
    String type = Source.updateStockTechnicalForDate;
    if (await isDataExist(date, type)) {
      return;
    }
    final dateStr =
        "${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}";
    final url = "https://www.tpex.org.tw/www/zh-tw/insti/dailyTrade";

    final body = {
      "type": "Daily",
      "sect": "AL",
      "date": dateStr,
      "id": "",
      "response": "json"
    };

    final response = await api.post(
        'event/get_url_data', {'url': url, 'method': 'POST', 'body': body});
    if (response['status'] != 'ok') return;
    Map dataSource = jsonDecode(response["data"]);

    List<dynamic> tables = dataSource["tables"];

    Map<String, int> enToIndex = {
      "stock_no": 0,
      "stock_name": 1,
      "foreign_buy": 2,
      "foreign_sell": 3,
      "foreign_diff": 4,
      "foreign_dealer_buy": 5,
      "foreign_dealer_sell": 6,
      "foreign_dealer_diff": 7,
      "trust_buy": 11,
      "trust_sell": 12,
      "trust_diff": 13,
      "dealer_diff": 22,
      "dealer_self_buy": 14,
      "dealer_self_sell": 15,
      "dealer_self_diff": 16,
      "dealer_hedge_buy": 17,
      "dealer_hedge_sell": 18,
      "dealer_hedge_diff": 19,
      "total_diff": 23,
    };

    List<dynamic> data = tables[0]["data"];
    List<Map<String, dynamic>> batch = [];
    for (int j = 0; j < data.length; j++) {
      final stockInstitutional =
          StockParser.parseT86(data[j], enToIndex, date, type);
      if (stockInstitutional == null) {
        continue;
      }
      batch.add(stockInstitutional);
      if (batch.length >= 500) {
        await api.post('stock/insert_stock_institutional_batch', {
          'table_name': TableNames.stockInstitutional,
          'stocks': batch,
        });
        batch.clear();
      }
    }
    if (batch.isNotEmpty) {
      await api.post('stock/insert_stock_institutional_batch', {
        'table_name': TableNames.stockInstitutional,
        'stocks': batch,
      });
      batch.clear();
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

    final response = await api.post('event/get_url_data', {
      'url': url,
      'method': 'GET',
    });
    if (response['status'] != 'ok') {
      return;
    }

    final rawData = jsonDecode(response["data"]);
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
        await api.post('stock/insert_stock_daily_price_batch', {
          'table_name': TableNames.stockDailyPrice,
          'stocks': batch,
        });
        batch.clear();
      }
    }
    if (batch.isNotEmpty) {
      await api.post('stock/insert_stock_daily_price_batch', {
        'table_name': TableNames.stockDailyPrice,
        'stocks': batch,
      });
      batch.clear();
    }
    await api.post('stock/insert_stock_date_batch', {
      'table_name': TableNames.stockDate,
      'stocks': [
        {
          'date': date.toUtc().toIso8601String(),
          'type': type,
        }
      ],
    });
  }

  Future<void> insertStockInstitutionalToSupabase(DateTime date) async {
    String type = Source.updateStockTechnicalForDate;
    if (await isDataExist(date, type)) {
      return;
    }
    final result = await api.post('stock/select_stock_institutional', {
      'date': DateFormat('yyyy-MM-dd').format(date),
    });

    await apiSupabase.post('stock/insert_stock_institutional_batch', {
      'table_name': TableNames.stockInstitutional,
      'stocks': result,
    });
  }

  Future<List<ModelInstitutional>> selectStockInstitutional(
      DateTime date) async {
    final result =
        await apiSupabase.post('stock/select_stock_institutional_by_table', {
      'date': DateFormat('yyyy-MM-dd').format(date),
    });
    return result
        .map<ModelInstitutional>((e) => ModelInstitutional.fromJson(e))
        .toList();
  }

  Future<void> loadFuturesInstitutional(DateTime date) async {
    String type = Source.updateStockTechnicalForDate;
    if (await isDataExist(date, type)) {
      return;
    }
    final dateStr =
        "${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}";

    final url = "https://www.taifex.com.tw/cht/3/futContractsDateDown"
        "?queryStartDate=$dateStr"
        "&queryEndDate=$dateStr";

    final response = await api.post('event/get_url_data', {
      'url': url,
      'method': 'GET',
    });

    if (response['status'] != 'ok') return;

    try {
      final csvText = response['data'];
      List<String> lines = csvText.split(RegExp(r'\r?\n'));
      lines.removeAt(0); // 移除標題行

      List<Map<String, dynamic>> result = [];

      for (final line in lines) {
        final cols = line.split(',');

        if (cols.length < 15) continue;

        result.add({
          "date": DateFormat('yyyy-MM-dd').format(date),
          "product_name": cols[1],
          "identity_type": cols[2],
          "trade_long_qty": cols[3],
          "trade_long_amount": cols[4],
          "trade_short_qty": cols[5],
          "trade_short_amount": cols[6],
          "trade_net_qty": cols[7],
          "trade_net_amount": cols[8],
          "oi_long_qty": cols[9],
          "oi_long_amount": cols[10],
          "oi_short_qty": cols[11],
          "oi_short_amount": cols[12],
          "oi_net_qty": cols[13],
          "oi_net_amount": cols[14],
        });
      }
      await api.post('stock/insert_futures_institutional_batch', {
        'table_name': TableNames.futuresInstitutional,
        'futures': result,
      });
    } catch (ex) {
      logger.e(ex);
    }
  }

  Future<void> insertFuturesToSupabase(DateTime date) async {
    String type = Source.updateStockTechnicalForDate;
    if (await isDataExist(date, type)) {
      return;
    }
    final result = await api.post('stock/select_futures_institutional', {
      'date': DateFormat('yyyy-MM-dd').format(date),
    });

    await apiSupabase.post('stock/insert_futures_institutional_batch', {
      'table_name': TableNames.futuresInstitutional,
      'futures': result,
    });
  }

  Future<List<ModelFuture>> selectFutures(DateTime date) async {
    final result =
        await apiSupabase.post('stock/select_futures_institutional', {
      'date': DateFormat('yyyy-MM-dd').format(date),
    });
    DateTime tmpDate = date;
    List result2 = [];
    try {
      while(result2.isEmpty) {
        tmpDate = tmpDate.subtract(Duration(days: 1));
        result2 = await apiSupabase.post('stock/select_futures_institutional', {
          'date': DateFormat('yyyy-MM-dd').format(tmpDate),
        });
      }
    } catch (ex) {
      logger.e(ex);
    }

     final Map<String, int> yesterdayMap = {
      for (var e in result2)
        "${e['product_name']}_${e['identity_type']}": e['oi_net_qty'] ?? 0,
    };

    return result.map<ModelFuture>((e) {
      final key = "${e['product_name']}_${e['identity_type']}";

      final todayQty = e['oi_net_qty'] ?? 0;
      final yQty = yesterdayMap[key] ?? 0;

      return ModelFuture.fromJson({
        ...e,
        "oi_net_qty_diff": todayQty - yQty,
      });
    }).toList();
  }

  Future<bool> isDataExist(DateTime date, String type) async {
    final result = await api.post('stock/check_stock_date', {
      'table_name': TableNames.stockDate,
      'date': date.toIso8601String(),
      'type': type,
    });
    return result["status"] == true;
  }

  Future<List<ModelStock>> getByDate(DateTime date) async {
    final result = await api.post('stock/select_stock_daily_price_by_date', {
      'table_name': TableNames.stockDailyPrice,
      'date': date.toIso8601String(),
      'traded_number': 20000000,
    });

    return result.map<ModelStock>((e) => ModelStock.fromJson(e)).toList();
  }

  Future<DateTime?> getLatestDateMac() async {
    final result = await api.post('stock/select_latest_stock_date', {
      'table_name': TableNames.stockDate,
      'type': Source.updateStockTechnicalForDate
    });
    if (result["date"] == null) {
      return null;
    }
    return DateTime.parse(result["date"]);
  }

  Future<DateTime?> getLatestDate() async {
    final result = await apiSupabase.post('stock/select_latest_stock_date', {
      'table_name': TableNames.stockDate,
      'type': Source.updateStockTechnicalForDate
    });
    if (result["date"] == null) {
      return null;
    }
    return DateTime.parse(result["date"]);
  }

  Future<List<ModelStock>> getSimpleStrategy(String level) async {
    try {
      // 1️⃣ 找最新日期
      final latestDate = await getLatestDateMac();
      if (latestDate == null) {
        return [];
      }

      // 2️⃣ 抓該日全部股票
      List<ModelStock> allStocks = await getByDate(latestDate);

      /*close >= high20	今日收盤突破過去 20 日高點 → 剛起漲
        volume >= vol5*1.5	成交量放大 → 市場有力道
        pct_change >= 2	當日漲幅 >2% → 明顯起漲
        ma5 >= ma20	均線多頭排列 → 趨勢向上*/
      List<ModelStock> risingStocks = filterRisingStocks(allStocks);

      // 4️⃣ 合併（避免重複）
      Map<String, ModelStock> map = {
        for (var s in risingStocks) s.securityCode: s,
      };

      try {
        List<ModelStock>? apiStocks = await fetchStocksFromApiMac(latestDate);
        if (apiStocks != null && apiStocks.isNotEmpty) {
          for (var s in apiStocks) {
            s.securityName = "API: ${s.securityName}";
            s.level = level;
            map.putIfAbsent("API: ${s.securityCode}", () => s);
          }
        }
      } catch (ex) {
        logger.e(ex);
      }

      // 👉 下一步：量化排序
      List<ModelStock> ranked = _rankStocks(allStocks);

      for (var s in ranked.take(200)) {
        map.putIfAbsent(s.securityCode, () => s);
      }

      stocks = map.values.toList();
      return stocks;
    } catch (ex, stackTrace) {
      logger.e(stackTrace);
      // 1️⃣ 找最新日期
      return getSimpleStrategySupabase("$level (lost server)");
    }
  }

  Future<List<ModelStock>> getSimpleStrategySupabase(String level) async {
    // 1️⃣ 找最新日期
    DateTime? latestDate = await getLatestDate();
    if (latestDate == null) {
      return [];
    }

    Map<String, ModelStock> map = {};

    try {
      List<ModelStock> apiStocks = await fetchStocksFromApi(latestDate);

      for (var s in apiStocks) {
        s.securityName = "API: ${s.securityName}";
        s.level = level;
        map.putIfAbsent("API: ${s.securityCode}", () => s);
      }
    } catch (ex) {
      logger.e(ex);
    }

    stocks = map.values.toList();
    return stocks;
  }

  Future<List<ModelStock>?> fetchStocksFromApiMac(DateTime date) async {
    // 檢查同一天是否已經有資料
    final existing = await api.post('stock/select_stock_predicted', {
      'table_name': TableNames.stockPredicted,
      'date': date.toIso8601String()
    });
    dynamic tmp;
    if (existing["data"] == null) {
      //api.post('stock/update_model', {});
      return null;
    }
    tmp = existing["data"];
    return (tmp as List)
        .map<ModelStock>(
            (json) => ModelStock.fromJson(Map<String, dynamic>.from(json)))
        .toList();
  }

  Future<List<ModelStock>> fetchStocksFromApi(DateTime date) async {
    // 檢查同一天是否已經有資料
    final existing = await apiSupabase.post('stock/select_stock_predicted', {
      'table_name': TableNames.stockPredicted,
      'date': date.toIso8601String()
    });
    dynamic tmp;
    if (existing["data"] == null || existing["data"].length == 0) {
      try {
        List<ModelStock>? apiStocks = await fetchStocksFromApiMac(date.toUtc());
        if (apiStocks != null && apiStocks.isNotEmpty) {
          await insertFromApi(apiStocks, date);
        }
      } catch (ex) {
        logger.e(ex);
      }
      return [];
    }
    tmp = existing["data"];
    return (tmp as List)
        .map<ModelStock>(
            (json) => ModelStock.fromJson(Map<String, dynamic>.from(json)))
        .toList();
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
          pct >= 2 && // 3️⃣ 漲幅 > 2%
          ma5 >= ma20 && // 4️⃣ 均線多頭
          rsi >= 50 &&
          s.closingPrice >= 20 &&
          s.tradedNumber != null &&
          s.tradedNumber! >= 35000000;

      //&& rsi < 80; //排除假突破與過熱

      if (isRising) {
        s.isRising = true; // 👈 標記
      }
      return isRising;
    }).toList()
      ..sort((a, b) => (b.pctChange ?? 0).compareTo(a.pctChange ?? 0));
  }

  Future<void> quantitativeCalculation(int batch, DateTime date) async {
    /*ma5           → 5日均線
      ma20          → 20日均線
      high20        → 過去20日最高收盤價
      pctChange     → 當日漲幅 %
      vol5        → 最近5日平均成交量*/
    final result = await api.post('stock/select_stock_quantitative_count', {
      'table_name': TableNames.stockDailyPrice,
      'date': date.toUtc().toIso8601String()
    });
    if (result["count"] == 0) {
      try {
        await api.post('stock/insert_stock_date_batch', {
          'table_name': TableNames.stockDate,
          'stocks': [
            {
              'date': date.toUtc().toIso8601String(),
              'type': Source.updateStockTechnicalForDate,
            }
          ],
        });
      } catch (ex) {
        logger.e(ex);
      }
      return;
    }

    stocksLength = (result["count"] / batch).ceil();
    for (int i = 0; i < stocksLength!; i++) {
      await api.post('stock/update_stock_technical_for_date', {
        'p_date': date.toUtc().toIso8601String(),
        'p_start': 1,
        'p_end': i == stocksLength! - 1 ? result["count"] - i * batch : batch,
      });
    }
    await api.post('stock/insert_stock_date_batch', {
      'table_name': TableNames.stockDate,
      'stocks': [
        {
          'date': date.toUtc().toIso8601String(),
          'type': Source.updateStockTechnicalForDate,
        }
      ],
    });
    await api.post('stock/update_model', {});

    await apiSupabase.post('stock/insert_stock_date_batch', {
      'table_name': TableNames.stockDate,
      'stocks': [
        {
          'date': date.toUtc().toIso8601String(),
          'type': Source.updateStockTechnicalForDate,
        }
      ],
    });

    try {
      List<ModelStock>? apiStocks = await fetchStocksFromApiMac(date.toUtc());
      if (apiStocks != null && apiStocks.isNotEmpty) {
        await insertFromApi(apiStocks, date);
      }
    } catch (ex) {
      logger.e(ex);
    }
  }

  Future<void> insertFromApi(List<ModelStock> stocks, DateTime date) async {
    // 檢查同一天是否已經有資料
    final existing = await apiSupabase.post('stock/select_stock_predicted', {
      'table_name': TableNames.stockPredicted,
      'date': date.toUtc().toIso8601String()
    });
    if (existing["data"] != null) {
      return;
    }
    await apiSupabase.post('stock/insert_stock_predicted', {
      'table_name': TableNames.stockPredicted,
      'date': date.toUtc().toIso8601String(),
      'stocks': stocks.map((stock) => stock.toJsonPred()).toList()
    });
  }
}

class SimpleStrategy {
  static double score(ModelStock s) {
    double score = 0;

    //綜合考量：漲幅 成交量 本益比 動能
    // 1️⃣ 短中期動能（核心）
    score += (s.pctChange ?? 0) * 2;
    score += (s.ma5 ?? 0) / s.closingPrice * 2;
    score += (s.ma20 ?? 0) / s.closingPrice * 1.5;

    // 2️⃣ 量能爆發
    if (s.vol5 != null && s.vol5! > 0) {
      score += (s.tradedNumber! / s.vol5!) * 5;
    }

    // 3️⃣ 突破強度
    if (s.high20 != null && s.high20! > 0) {
      score += (s.closingPrice / s.high20!) * 20;
    }

    // 4️⃣ RSI 動能
    if (s.rsi != null) {
      score += s.rsi! * 0.3;
    }

    // 5️⃣ K棒強度
    if (s.highestPrice != null && s.lowestPrice != null) {
      double range = s.highestPrice! - s.lowestPrice!;
      if (range > 0) {
        double strength = (s.closingPrice - s.lowestPrice!) / range;
        score += strength * 10;
      }
    }

    // 6️⃣ 均線結構
    if (s.ma5 != null && s.ma20 != null) {
      if (s.ma5! > s.ma20!) {
        score += 10;
      }
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

  static Map<String, dynamic>? parseT86(
      List row, Map<String, int> enToIndex, DateTime date, String source) {
    try {
      String get(String key) {
        final i = enToIndex[key];
        if (i == null) return "0";
        return row[i].toString().replaceAll(",", "");
      }

      return {
        "date": date.toUtc().toIso8601String(),
        "stock_no": row[enToIndex["stock_no"]!],
        "stock_name": row[enToIndex["stock_name"]!],
        "foreign_buy": int.parse(get("foreign_buy")),
        "foreign_sell": int.parse(get("foreign_sell")),
        "foreign_diff": int.parse(get("foreign_diff")),
        "foreign_dealer_buy": int.parse(get("foreign_dealer_buy")),
        "foreign_dealer_sell": int.parse(get("foreign_dealer_sell")),
        "foreign_dealer_diff": int.parse(get("foreign_dealer_diff")),
        "trust_buy": int.parse(get("trust_buy")),
        "trust_sell": int.parse(get("trust_sell")),
        "trust_diff": int.parse(get("trust_diff")),
        "dealer_diff": int.parse(get("dealer_diff")),
        "dealer_self_buy": int.parse(get("dealer_self_buy")),
        "dealer_self_sell": int.parse(get("dealer_self_sell")),
        "dealer_self_diff": int.parse(get("dealer_self_diff")),
        "dealer_hedge_buy": int.parse(get("dealer_hedge_buy")),
        "dealer_hedge_sell": int.parse(get("dealer_hedge_sell")),
        "dealer_hedge_diff": int.parse(get("dealer_hedge_diff")),
        "total_diff": int.parse(get("total_diff")),
        "source": source,
      };
    } catch (e) {
      logger.e(row[enToIndex["stock_name"]!]);
      return null;
    }
  }
}
