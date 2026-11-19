import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final sql = File(
    'supabase/migrations/20261119000100_external_cache_batches.sql',
  ).readAsStringSync();

  test('weather and holiday cache batches are bounded and authenticated', () {
    expect(sql, contains('life_pilot_cached_weather_batch'));
    expect(sql, contains('jsonb_array_length(p_locations) not between 1 and 8'));
    expect(sql, contains('life_pilot_cached_holidays_batch'));
    expect(sql, contains('cardinality(p_years), 0) not between 1 and 4'));
    expect(sql, contains('if auth.uid() is null then'));
    expect(sql, contains('from public, anon'));
    expect(sql, contains('to authenticated, service_role'));
  });

  test('batch cache responses preserve input order and do not refresh data', () {
    expect(sql, contains('order by requested.ordinality'));
    expect(sql, contains('cache.expires_at > now()'));
    expect(sql, contains("status = 'success'"));
    expect(sql, isNot(contains('insert into public.weather_forecast_cache')));
    expect(sql, isNot(contains('insert into public.public_holidays')));
  });

  test('legacy holiday RPC retirement is audited and dependency safe', () {
    final audit = File(
      'supabase/manual/20261119_audit_single_holiday_cache_rpc.sql',
    ).readAsStringSync();
    final retirement = File(
      'supabase/manual/20261119_retire_single_holiday_cache_rpc.sql',
    ).readAsStringSync();
    expect(audit, contains('registered_dependents'));
    expect(audit, contains('possible_function_callers'));
    expect(audit, contains('possible_policy_callers'));
    expect(audit, contains('possible_setting_callers'));
    expect(audit, contains('entitlement_legacy_rows'));
    expect(retirement, contains('drop function if exists'));
    expect(retirement, contains('restrict'));
    expect(retirement, isNot(contains('cascade')));
  });
}
