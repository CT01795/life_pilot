import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('dashboard account selectors use lightweight option services', () {
    final accounting = File(
      'lib/accounting/service_accounting.dart',
    ).readAsStringSync();
    final points = File(
      'lib/point_record/service_point_record.dart',
    ).readAsStringSync();

    final accountSelector = File(
      'lib/pages/home/widgets/dashboard/account_selector_button.dart',
    ).readAsStringSync();
    final pointSelector = File(
      'lib/pages/home/widgets/dashboard/point_selector_button.dart',
    ).readAsStringSync();

    expect(accountSelector, contains('.fetchAccountOptions('));
    expect(pointSelector, contains('.fetchAccountOptions('));
    for (final source in [accounting, points]) {
      expect(source, isNot(contains('int? projectLimit')));
      expect(source, isNot(contains("'get_my_ledger_account_options'")));
    }
  });

  test('combined account option RPC is authenticated, bounded and light', () {
    final sql = File(
      'supabase/migrations/20261118000500_lightweight_ledger_account_options.sql',
    ).readAsStringSync();

    expect(sql, contains("p_kind not in ('accounting', 'points')"));
    expect(sql, contains('auth.uid() is null'));
    expect(sql, contains('lower(trim(a.created_by)) = v_email'));
    expect(sql, contains('recent.position <= v_limit'));
    expect(sql, contains('to authenticated, service_role'));
    expect(sql, contains("notify pgrst, 'reload schema'"));
    expect(sql, isNot(contains("'balance',")));
    expect(sql, isNot(contains("'points',")));
    expect(sql, isNot(contains("'main_currency',")));
    expect(sql, isNot(contains("'exchange_rate',")));
  });
}
