// lib/models/stock.dart
import 'package:life_pilot/utils/value_parser.dart';

class ModelStock {
  DateTime date;
  String securityCode;
  String securityName;
  double? tradedNumber;
  int? transactionsNumber;
  double? transactionAmount;
  double? openingPrice;
  double? highestPrice;
  double? lowestPrice;
  double closingPrice;
  String? change;
  double? priceDifference;
  double? finalRevealBuyingPrice;
  double? finalRevealBuyingVolume;
  double? finalRevealSellingPrice;
  double? finalRevealSellingVolume;
  double? peRatio;
  String? source;
  double? ma5;
  double? ma20;
  double? high20;
  double? pctChange;
  double? vol5;
  double? rsi;
  bool? isRising;
  double? predPct;
  int? signal;
  String? signalText;
  String? level;

  ModelStock({
    required this.date,
    required this.securityCode,
    required this.securityName,
    this.tradedNumber,
    this.transactionsNumber,
    this.transactionAmount,
    this.openingPrice,
    this.highestPrice,
    this.lowestPrice,
    required this.closingPrice,
    this.change,
    this.priceDifference,
    this.finalRevealBuyingPrice,
    this.finalRevealBuyingVolume,
    this.finalRevealSellingPrice,
    this.finalRevealSellingVolume,
    this.peRatio,
    this.source,
    this.ma5,
    this.ma20,
    this.high20,
    this.pctChange,
    this.vol5,
    this.rsi,
    this.isRising,
    this.predPct,
    this.signal,
    this.signalText,
    this.level,
  });

  Map<String, dynamic> toJson() {
    return {
      'date': date.toUtc().toIso8601String(),
      'security_code': securityCode,
      'security_name': securityName,
      'traded_number': tradedNumber,
      'transactions_number': transactionsNumber,
      'transaction_amount': transactionAmount,
      'opening_price': openingPrice,
      'highest_price': highestPrice,
      'lowest_price': lowestPrice,
      'closing_price': closingPrice,
      'change': change,
      'price_difference': priceDifference,
      'final_reveal_buying_price': finalRevealBuyingPrice,
      'final_reveal_buying_volume': finalRevealBuyingVolume,
      'final_reveal_selling_price': finalRevealSellingPrice,
      'final_reveal_selling_volume': finalRevealSellingVolume,
      'pe_ratio': peRatio,
      'source': source,
      'ma5': ma5,
      'ma20': ma20,
      'high20': high20,
      'pct_change': pctChange,
      'vol5': vol5,
      'rsi': rsi,
    };
  }

  Map<String, dynamic> toJsonPred() {
    return {
      'date': date.toUtc().toIso8601String(),
      'security_code': securityCode,
      'security_name': securityName,
      'traded_number': tradedNumber,
      'transactions_number': transactionsNumber,
      'transaction_amount': transactionAmount,
      'opening_price': openingPrice,
      'highest_price': highestPrice,
      'lowest_price': lowestPrice,
      'closing_price': closingPrice,
      'change': change,
      'price_difference': priceDifference,
      'final_reveal_buying_price': finalRevealBuyingPrice,
      'final_reveal_buying_volume': finalRevealBuyingVolume,
      'final_reveal_selling_price': finalRevealSellingPrice,
      'final_reveal_selling_volume': finalRevealSellingVolume,
      'pe_ratio': peRatio,
      'source': source,
      'ma5': ma5,
      'ma20': ma20,
      'high20': high20,
      'pct_change': pctChange,
      'vol5': vol5,
      'rsi': rsi,
      'pred_pct': predPct,
      'signal': signal,
      'signal_text': signalText,
    };
  }

  factory ModelStock.fromJson(Map<String, dynamic> json) {
    return ModelStock(
      date: DateTime.parse(json['date'].toString()),
      securityCode: json['security_code'],
      securityName: json['security_name'],
      tradedNumber: tryParseDoubleValue(json['traded_number']),
      transactionsNumber: tryParseIntValue(json['transactions_number']),
      transactionAmount: tryParseDoubleValue(json['transaction_amount']),
      openingPrice: tryParseDoubleValue(json['opening_price']),
      highestPrice: tryParseDoubleValue(json['highest_price']),
      lowestPrice: tryParseDoubleValue(json['lowest_price']),
      closingPrice: parseDoubleValue(json['closing_price']),
      change: json['change']?.toString(),
      priceDifference: tryParseDoubleValue(json['price_difference']),
      finalRevealBuyingPrice: tryParseDoubleValue(
        json['final_reveal_buying_price'],
      ),
      finalRevealBuyingVolume: tryParseDoubleValue(
        json['final_reveal_buying_volume'],
      ),
      finalRevealSellingPrice: tryParseDoubleValue(
        json['final_reveal_selling_price'],
      ),
      finalRevealSellingVolume: tryParseDoubleValue(
        json['final_reveal_selling_volume'],
      ),
      peRatio: tryParseDoubleValue(json['pe_ratio']),
      source: json['source']?.toString(),
      ma5: tryParseDoubleValue(json['ma5']),
      ma20: tryParseDoubleValue(json['ma20']),
      high20: tryParseDoubleValue(json['high20']),
      pctChange: tryParseDoubleValue(json['pct_change']),
      vol5: tryParseDoubleValue(json['vol5']),
      rsi: tryParseDoubleValue(json['rsi']),
      predPct: tryParseDoubleValue(json['pred_pct']),
      signal: tryParseIntValue(json['signal']),
      signalText: json['signal_text'],
    );
  }
}

class ModelFuture {
  String? productName;
  String? identityType;

  int? oiLongQty;
  int? oiShortQty;
  int? oiNetQty;
  int? oiNetQtyDiff;

  ModelFuture({
    this.productName,
    this.identityType,
    this.oiLongQty,
    this.oiShortQty,
    this.oiNetQty,
    this.oiNetQtyDiff,
  });

  factory ModelFuture.fromJson(Map<String, dynamic> json) {
    return ModelFuture(
      productName: json['product_name'],
      identityType: json['identity_type'],
      oiLongQty: tryParseIntValue(json['oi_long_qty']),
      oiShortQty: tryParseIntValue(json['oi_short_qty']),
      oiNetQty: tryParseIntValue(json['oi_net_qty']),
      oiNetQtyDiff: tryParseIntValue(json['oi_net_qty_diff']),
    );
  }
}

class ModelInstitutional {
  String stockNo;
  String stockName;
  int foreignDiff;
  int totalDiff;

  ModelInstitutional({
    required this.stockNo,
    required this.stockName,
    required this.foreignDiff,
    required this.totalDiff,
  });

  factory ModelInstitutional.fromJson(Map<String, dynamic> json) {
    return ModelInstitutional(
      stockNo: json['stock_no']?.toString() ?? '',
      stockName: json['stock_name']?.toString() ?? '',
      foreignDiff: parseIntValue(json['foreign_diff']),
      totalDiff: parseIntValue(json['total_diff']),
    );
  }
}
