import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/stock/stock_parser.dart';

void main() {
  final date = DateTime.utc(2026, 10, 14);
  final columns = <String, int>{
    'security_code': 0,
    'security_name': 1,
    'closing_price': 2,
    'price_difference': 3,
    'change': 4,
    'traded_number': 5,
    'transactions_number': 6,
    'transaction_amount': 7,
    'opening_price': 8,
    'highest_price': 9,
    'lowest_price': 10,
    'final_reveal_buying_price': 11,
    'final_reveal_buying_volume': 12,
    'final_reveal_selling_price': 13,
    'final_reveal_selling_volume': 14,
    'pe_ratio': 15,
  };
  List<Object?> validRow() => [
    '2330',
    'Example',
    '1,234.5',
    '-10.5',
    '-',
    '10,000',
    '1,000',
    '12,345,000',
    1240,
    1250,
    1230,
    1234,
    200,
    1235,
    300,
    '25.5',
  ];

  test('daily prices parse decimal and comma-formatted source values', () {
    final stock = StockParser.parse(validRow(), columns, date, false, 'test')!;
    expect(stock.securityCode, '2330');
    expect(stock.closingPrice, 1234.5);
    expect(stock.priceDifference, 10.5);
    expect(stock.tradedNumber, 10000);
    expect(stock.transactionsNumber, 1000);
    expect(stock.transactionAmount, 12345000);
    expect(stock.peRatio, 25.5);
  });

  test('OTC derives change from difference and has no PE ratio', () {
    final row = validRow()..[3] = '10.5';
    final stock = StockParser.parse(row, columns, date, true, 'test')!;
    expect(stock.change, '+');
    expect(stock.peRatio, isNull);
  });

  test('invalid security codes and closing prices are rejected', () {
    expect(
      StockParser.parse(validRow()..[0] = '12', columns, date, false, 'test'),
      isNull,
    );
    expect(
      StockParser.parse(validRow()..[2] = '--', columns, date, false, 'test'),
      isNull,
    );
  });

  test('missing or out-of-range daily columns return no record', () {
    expect(StockParser.parse([], columns, date, false, 'test'), isNull);
    expect(StockParser.parse(validRow(), {}, date, false, 'test'), isNull);
  });

  test('institutional rows default absent counters to zero', () {
    final result = StockParser.parseT86(
      ['2330', 'Example', '1,000', '-200'],
      {'stock_no': 0, 'stock_name': 1, 'foreign_buy': 2, 'foreign_diff': 3},
      date,
      'test',
    )!;
    expect(result['foreign_buy'], 1000);
    expect(result['foreign_diff'], -200);
    expect(result['trust_buy'], 0);
    expect(result['date'], date.toIso8601String());
  });

  test('malformed institutional rows never throw while logging errors', () {
    expect(StockParser.parseT86([], {}, date, 'test'), isNull);
    expect(
      StockParser.parseT86(
        ['2330'],
        {'stock_no': 0, 'stock_name': 9},
        date,
        'test',
      ),
      isNull,
    );
  });
}
