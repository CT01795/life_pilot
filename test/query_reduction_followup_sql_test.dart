import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String sql;

  setUpAll(() {
    sql = File(
      'supabase/migrations/20261112000300_query_reduction_followup.sql',
    ).readAsStringSync();
  });

  test('follow-up migration batches geocode cache and ledger defaults', () {
    expect(sql, contains('search_lat_lng_batch'));
    expect(sql, contains('get_my_ledger_entry_defaults'));
    expect(sql, contains('jsonb_array_length(p_queries) > 100'));
    expect(sql, contains('to authenticated, service_role'));
    expect(sql, contains('from public, anon'));
  });

  test('history supports long windows without returning null rows', () {
    expect(sql, contains("interval '36525 days'"));
    expect(sql, isNot(contains('limit 1001')));
    expect(sql, isNot(contains("'rows',case")));
  });

  test('legacy screenshot and quota paths fail closed before retirement', () {
    expect(sql, contains('feedback_screenshot_migration_incomplete'));
    expect(sql, contains('drop column if exists screenshot'));
    expect(sql, contains('subscription_snapshot_migration_incomplete'));
    expect(sql, contains("p_snapshot ->> p_resource"));
    expect(sql, isNot(contains("p_snapshot ->> quota_column")));
  });
}
