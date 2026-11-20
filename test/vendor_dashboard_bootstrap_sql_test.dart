import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('vendor dashboard bootstrap combines the three dashboard reads', () {
    final sql = File(
      'supabase/migrations/20261119000300_vendor_dashboard_bootstrap.sql',
    ).readAsStringSync();

    expect(sql, contains('get_my_vendor_subscription_status()'));
    expect(sql, contains('get_my_vendor_dashboard_metrics(p_day_start)'));
    expect(sql, contains("get_pricing_catalog(true) -> 'versions'"));
    expect(sql, contains('perform public.ensure_my_vendor_account()'));
    expect(sql, contains('recommended_events_vendor_active_idx'));
    expect(sql, contains('recommended_attractions_vendor_active_idx'));
    expect(
      sql,
      contains(
        'grant execute on function public.get_my_vendor_dashboard_bootstrap',
      ),
    );
    expect(sql, contains('to authenticated, service_role'));
    expect(sql, contains('from public, anon'));
  });

  test('vendor dashboard follow-up caches metrics and refreshes five cards', () {
    final sql = File(
      'supabase/migrations/20261120000100_vendor_dashboard_metrics_cache.sql',
    ).readAsStringSync();

    expect(sql, contains('life_pilot_cached_vendor_dashboard_metrics'));
    expect(sql, contains('get_my_vendor_dashboard_metrics(p_day_start)'));
    expect(sql, contains('vendor_dashboard_metrics_cache'));
    expect(sql, contains("interval '5 minutes'"));
    expect(sql, contains('p_force_refresh boolean default false'));
    expect(sql, contains('life_pilot_invalidate_vendor_metrics_cache'));
    expect(sql, contains('get_my_vendor_recent_submissions'));
    expect(
      sql,
      contains("jsonb_agg(to_jsonb(ranked) - 'ordinal' order by ordinal)"),
    );
    expect(
      sql,
      contains(
        'revoke all on table public.vendor_dashboard_metrics_cache\n  from public, anon, authenticated',
      ),
    );
  });
}
