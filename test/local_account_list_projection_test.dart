import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/accounting/model_ledger_account_option.dart';
import 'package:life_pilot/utils/model_local_account_list.dart';
import 'package:life_pilot/utils/record_row_utils.dart';

RecordRow _account(
  String id, {
  String category = 'personal',
  String currency = 'TWD',
  String created = '',
  bool valid = true,
}) => {
  'id': id,
  'category': category,
  'main_currency': currency,
  'created_at': created,
  'is_valid': valid,
};

void main() {
  test('selection keeps personal accounts and newest limited projects', () {
    final accounts = [
      _account('personal-2'),
      _account('old', category: 'project', created: '2020'),
      _account('personal-1'),
      _account('new', category: 'project', created: '2026'),
      _account('middle', category: 'project', created: '2025'),
      _account('invalid', valid: false),
      _account('other', category: 'unknown'),
    ];
    expect(
      ModelLedgerAccountOption.selectLocal(
        accounts,
        projectLimit: 2,
      ).map((option) => option.id),
      ['personal-1', 'personal-2', 'new', 'middle'],
    );
    expect(
      ModelLocalAccountList.selectAccounts(
        accounts: accounts,
        category: 'project',
      ).map((row) => row['id']),
      ['old', 'new', 'middle'],
    );
  });

  test('indexed totals use account and accounting currency keys', () {
    final twd = _account('a');
    final usd = _account('b', currency: 'USD');
    final page = ModelLocalAccountList.fromIndexedTotals(
      accounts: [twd, usd],
      totals: {('a', 'TWD'): 12.5, ('b', 'USD'): -3},
      points: false,
    );
    expect(page.totalFor(twd), 12.5);
    expect(page.totalFor(usd), -3);
    expect(() => page.rows.clear(), throwsUnsupportedError);
  });

  test('point totals ignore currency and missing totals remain zero', () {
    final first = _account('a');
    final second = _account('b', currency: 'USD');
    final page = ModelLocalAccountList.fromIndexedTotals(
      accounts: [first, second],
      totals: {('a', null): 25},
      points: true,
    );
    expect(page.totalFor(first), 25);
    expect(page.totalFor(second), 0);
  });

  test('negative project limit keeps the existing rejection rule', () {
    expect(
      () => ModelLedgerAccountOption.selectLocal([
        _account('a'),
      ], projectLimit: -1),
      throwsArgumentError,
    );
  });
}
