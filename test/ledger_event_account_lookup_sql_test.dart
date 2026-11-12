import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ledger event lookup is bounded and authenticated', () {
    final sql = File(
      'supabase/migrations/20261112000200_ledger_event_account_lookup.sql',
    ).readAsStringSync();

    expect(sql, contains('get_my_ledger_account_by_event'));
    expect(sql, contains("p_kind not in ('accounting', 'points')"));
    expect(sql, contains('account_row.id::text = p_event_id'));
    expect(sql, contains('detail.event_id::text = p_event_id'));
    expect(sql, contains('limit 1'));
    expect(sql, contains('to authenticated, service_role'));
    expect(sql, contains('from public, anon'));
  });
}
