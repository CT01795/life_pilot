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

    expect(accountSelector, contains('.fetchAccountOptionPage('));
    expect(pointSelector, contains('.fetchAccountOptionPage('));
    for (final source in [accounting, points]) {
      expect(source, isNot(contains('int? projectLimit')));
      expect(source, isNot(contains("'get_my_ledger_account_options'")));
      expect(source, contains('fetchAccountOptionPage'));
    }
  });

  test('combined owned/shared account picker uses search and cursor', () {
    final sql = File(
      'supabase/migrations/20261118000600_dashboard_ledger_picker.sql',
    ).readAsStringSync();

    expect(sql, contains("p_kind not in ('accounting', 'points')"));
    expect(sql, contains('auth.uid() is null'));
    expect(sql, contains('p_cursor jsonb'));
    expect(sql, contains('p_search text'));
    expect(sql, contains('p_selected_id text'));
    expect(sql, contains('public.ledger_read_shares'));
    expect(sql, contains("'shared_kind', s.kind"));
    expect(sql, contains('(f.sort_group, f.sort_name, f.sort_id)'));
    expect(
      sql,
      contains('drop function if exists public.get_my_ledger_account_options'),
    );
    expect(sql, contains('to authenticated, service_role'));
    expect(sql, contains("notify pgrst, 'reload schema'"));
    expect(sql, isNot(contains("'balance',")));
    expect(sql, isNot(contains("'points',")));
    expect(sql, isNot(contains("'main_currency',")));
    expect(sql, isNot(contains("'exchange_rate',")));
  });
}
