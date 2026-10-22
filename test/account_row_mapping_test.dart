import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/accounting/model_accounting_account.dart';
import 'package:life_pilot/point_record/model_point_record_account.dart';
import 'package:life_pilot/utils/value_parser.dart';

void main() {
  Map<String, dynamic> row() => {
    'id': 'account',
    'account': 'My account',
    'category': 'project',
    'main_currency': 'USD',
    'exchange_rate': 32.1234,
    'balance': '1234.5678',
    'points': '1234',
    'master_graph_url': 'not-a-base64-image',
  };

  test('accounting maps original fields and retains decimal precision', () {
    final account = ModelAccountingAccount.fromRow(row());
    expect(account.id, 'account');
    expect(account.accountName, 'My account');
    expect(account.category, 'project');
    expect(account.currency, 'USD');
    expect(account.exchangeRate, 32.1234);
    expect(account.balance, 1234.5678);
    expect(account.masterGraphUrl, null);
  });
  test('points maps original fields and numeric string values', () {
    final account = ModelPointRecordAccount.fromRow(row());
    expect(account.id, 'account');
    expect(account.accountName, 'My account');
    expect(account.category, 'project');
    expect(account.points, 1234);
    expect(account.masterGraphUrl, null);
  });
  for (final value in [null, '', 'invalid', 0, -23.4567, '23.4567']) {
    test('numeric conversion retains existing parser rules for $value', () {
      final values = row()
        ..['balance'] = value
        ..['points'] = value;
      expect(
        ModelAccountingAccount.fromRow(values).balance,
        parseNumValue(value),
      );
      expect(
        ModelPointRecordAccount.fromRow(values).points,
        parseIntValue(value),
      );
    });
  }
  test('local zero and negative totals override stale stored balances', () {
    for (final value in [0, -200]) {
      expect(
        ModelAccountingAccount.fromRow(row(), balanceOverride: value).balance,
        value,
      );
      expect(
        ModelPointRecordAccount.fromRow(row(), pointsOverride: value).points,
        value,
      );
    }
    expect(
      ModelAccountingAccount.fromRow(row(), balanceOverride: -23.4567).balance,
      -23.4567,
    );
  });
  test(
    'null and empty currencies remain distinct with no invented fallback',
    () {
      final values = row()
        ..['main_currency'] = null
        ..['exchange_rate'] = null;
      final missing = ModelAccountingAccount.fromRow(values);
      expect(missing.currency, null);
      expect(missing.exchangeRate, null);
      values['main_currency'] = '';
      expect(ModelAccountingAccount.fromRow(values).currency, '');
    },
  );
  test('only explicitly supplied decoded image bytes enter the model', () {
    final bytes = Uint8List.fromList([1, 2, 3]);
    expect(
      ModelAccountingAccount.fromRow(
        row(),
        masterGraphUrl: bytes,
      ).masterGraphUrl,
      same(bytes),
    );
    expect(
      ModelPointRecordAccount.fromRow(
        row(),
        masterGraphUrl: bytes,
      ).masterGraphUrl,
      same(bytes),
    );
  });
  test(
    'read-only input is neither changed nor converted into display labels',
    () {
      final values = Map<String, dynamic>.unmodifiable(row());
      ModelAccountingAccount.fromRow(values);
      ModelPointRecordAccount.fromRow(values);
      expect(values, row());
    },
  );
  test('required identifiers are not silently replaced with empty values', () {
    final values = row()..remove('id');
    expect(
      () => ModelAccountingAccount.fromRow(values),
      throwsA(isA<TypeError>()),
    );
    expect(
      () => ModelPointRecordAccount.fromRow(values),
      throwsA(isA<TypeError>()),
    );
  });
}
