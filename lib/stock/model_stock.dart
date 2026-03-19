// lib/models/stock.dart
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

  ModelStock(
      {required this.date,
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
      this.isRising});

  Map<String, dynamic> toJson() {
    return {
      'date': date.toIso8601String(),
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
      'pctChange': pctChange,
      'vol5': vol5,
      'rsi': rsi,
    };
  }

  factory ModelStock.fromJson(Map<String, dynamic> json) {
    return ModelStock(
      date: DateTime.parse(json['date']),
      securityCode: json['security_code'],
      securityName: json['security_name'],
      tradedNumber: (json['traded_number'] as num?)?.toDouble(),
      transactionsNumber: json['transactions_number'] as int?,
      transactionAmount: (json['transaction_amount'] as num?)?.toDouble(),
      openingPrice: (json['opening_price'] as num?)?.toDouble(),
      highestPrice: (json['highest_price'] as num?)?.toDouble(),
      lowestPrice: (json['lowest_price'] as num?)?.toDouble(),
      closingPrice: (json['closing_price'] as num?)?.toDouble() ?? 0,
      change: json['change']?.toString(),
      priceDifference: (json['price_difference'] as num?)?.toDouble(),
      finalRevealBuyingPrice:
          (json['final_reveal_buying_price'] as num?)?.toDouble(),
      finalRevealBuyingVolume:
          (json['final_reveal_buying_volume'] as num?)?.toDouble(),
      finalRevealSellingPrice:
          (json['final_reveal_selling_price'] as num?)?.toDouble(),
      finalRevealSellingVolume:
          (json['final_reveal_selling_volume'] as num?)?.toDouble(),
      peRatio: (json['pe_ratio'] as num?)?.toDouble(),
      source: json['source']?.toString(),
      ma5: (json['ma5'] as num?)?.toDouble(),
      ma20: (json['ma20'] as num?)?.toDouble(),
      high20: (json['high20'] as num?)?.toDouble(),
      pctChange: (json['pctChange'] as num?)?.toDouble(),
      vol5: (json['vol5'] as num?)?.toDouble(),
      rsi: (json['rsi'] as num?)?.toDouble(),
    );
  }
}
