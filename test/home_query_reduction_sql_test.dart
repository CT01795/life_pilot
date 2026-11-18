import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('home recommendation and shared snapshots are set based', () {
    final sql = File(
      'supabase/migrations/20261117000400_home_recommendations_and_shared_snapshots.sql',
    ).readAsStringSync();

    expect(sql, contains('get_home_recommendations'));
    expect(sql, contains('get_home_recommended_events'));
    expect(sql, contains('get_home_recommended_places'));
    expect(sql, contains('order by event_row.ordinality'));
    expect(sql, contains('order by place_row.ordinality'));
    expect(sql, contains('get_my_ledger_home_snapshots'));
    expect(sql, contains('row_number() over'));
    expect(sql, contains('position <= 5'));
    expect(sql, contains("'description', detail.description"));
    expect(sql, isNot(contains("'description', detail.title")));
    expect(sql, contains("p_month_start + interval '32 days'"));
    expect(sql, contains("p_day_start + interval '26 hours'"));
    expect(sql, contains("'shared_ledgers', v_shared"));
    expect(sql, isNot(contains('get_my_shared_ledger_home_preview(')));
    expect(sql, contains("notify pgrst, 'reload schema'"));
  });
}
