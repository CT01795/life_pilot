import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('dashboard bootstrap and unified address cache are secured', () {
    final sql = File(
      'supabase/migrations/20261112000400_dashboard_bootstrap_and_address_cache.sql',
    ).readAsStringSync();

    expect(sql, contains('get_or_create_my_dashboard_core'));
    expect(sql, contains('on conflict (account) do nothing'));
    expect(
      RegExp(
        'get_my_dashboard_ledger_summary',
        caseSensitive: false,
      ).allMatches(sql),
      hasLength(2),
    );
    expect(sql, contains('life_pilot_resolve_cached_address'));
    expect(sql, contains('life_pilot_geocode_cache_result(p_query)'));
    expect(sql, contains('to authenticated, service_role'));
    expect(sql, contains("notify pgrst, 'reload schema'"));
  });
}
