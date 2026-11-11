import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('account and point option lists use one combined RPC', () {
    final accounting = File(
      'lib/accounting/service_accounting.dart',
    ).readAsStringSync();
    final points = File(
      'lib/point_record/service_point_record.dart',
    ).readAsStringSync();

    for (final source in [accounting, points]) {
      expect(source, contains("'get_my_ledger_account_options'"));
      expect(source, isNot(contains('final responses = await Future.wait')));
    }
    expect(accounting, contains("'p_kind': 'accounting'"));
    expect(points, contains("'p_kind': 'points'"));
  });

  test('combined account option RPC is authenticated and bounded', () {
    final sql = File(
      'supabase/migrations/20261111000800_ledger_account_options.sql',
    ).readAsStringSync();

    expect(sql, contains("p_kind not in ('accounting', 'points')"));
    expect(sql, contains('auth.uid() is null'));
    expect(sql, contains('lower(trim(a.created_by)) = v_email'));
    expect(sql, contains('recent.position <= v_limit'));
    expect(sql, contains('to authenticated, service_role'));
    expect(sql, contains("notify pgrst, 'reload schema'"));
  });
}
