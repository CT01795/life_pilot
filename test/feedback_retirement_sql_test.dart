import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('legacy feedback page retirement is dependency safe', () {
    final sql = File(
      'supabase/migrations/20261118000100_retire_legacy_feedback_pages.sql',
    ).readAsStringSync();

    expect(sql, contains('get_feedback_summary_page'));
    expect(sql, contains('legacy_feedback_page_still_called'));
    expect(sql, contains('drop function %s restrict'));
    expect(sql, isNot(contains(' drop function %s cascade')));
  });

  test('subscription quota migration accepts canonical snapshots only', () {
    final sql = File(
      'supabase/migrations/20261112000300_query_reduction_followup.sql',
    ).readAsStringSync();

    expect(sql, contains('subscription_snapshot_migration_incomplete'));
    expect(sql, contains("entitlement_snapshot ->> 'calendar_events'"));
    expect(sql, contains("entitlement_snapshot ->> 'image_bytes'"));
    expect(
      sql,
      isNot(contains("active.entitlement_snapshot ->> 'calendar_quota'")),
    );
    expect(
      sql,
      isNot(contains("active.entitlement_snapshot ->> 'image_megabytes'")),
    );
  });

  test('ledger name search indexes match owner and category paging', () {
    final sql = File(
      'supabase/migrations/20261118000200_ledger_account_search_indexes.sql',
    ).readAsStringSync();

    expect(sql, contains('accounting_account (created_by, category, account)'));
    expect(
      sql,
      contains('point_record_account (created_by, category, account)'),
    );
    expect(sql, contains('where is_valid is true'));
  });
}
