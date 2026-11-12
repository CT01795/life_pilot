import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('query reduction bundle exposes bounded authenticated RPCs', () {
    final sql = File(
      'supabase/migrations/20261112000100_query_reduction_bundle.sql',
    ).readAsStringSync();
    expect(sql, contains('get_my_business_plan_window'));
    expect(sql, contains("'next_before'"));
    expect(sql, contains("'has_more'"));
    expect(sql, contains('calendar_has_recommended_place'));
    expect(sql, contains('get_home_recommendation_city_counts'));
    expect(sql, contains('to authenticated, service_role'));
    expect(
      sql,
      isNot(
        contains(
          'grant execute on function public.get_my_business_plan_window(timestamptz, boolean, integer)\n  to anon',
        ),
      ),
    );
  });
}
