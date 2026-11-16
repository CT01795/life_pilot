import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'dashboard v2 includes selected shared ledgers and compact previews',
    () {
      final sql = File(
        'supabase/migrations/20261116000100_dashboard_shared_bootstrap.sql',
      ).readAsStringSync();

      expect(sql, contains('get_or_create_my_dashboard_core_v2'));
      expect(sql, contains('list_my_ledger_home_links()'));
      expect(sql, contains('get_my_shared_ledger_home_preview'));
      expect(sql, contains('p_month_start'));
      expect(sql, contains('p_month_end'));
      expect(sql, isNot(contains("date_trunc('month', p_day_start)")));
      expect(sql, contains("'shared_ledgers', v_shared"));
      expect(sql, contains('to authenticated, service_role'));
      expect(sql, contains("notify pgrst, 'reload schema'"));
    },
  );
}
