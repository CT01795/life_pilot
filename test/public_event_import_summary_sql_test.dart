import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('deduplication reads both sources once and import returns summary', () {
    final sql = File(
      'supabase/migrations/20261111001000_public_event_import_summary.sql',
    ).readAsStringSync();
    expect(sql, contains('get_public_event_deduplication_rows_v2'));
    expect(sql, contains('union all'));
    expect(sql, contains("'received_rows', v_received"));
    expect(sql, contains("'inserted_rows', v_inserted"));
    expect(sql, contains("'duplicate_rows'"));
    expect(sql, contains('duplicate_deleted_rows'));
    expect(sql, contains('duplicate_existing_rows'));
    expect(sql, contains('conflict_rows'));
    expect(sql, contains('to authenticated, service_role'));
  });

  test('retired deduplication v1 checks dynamic callers before dropping', () {
    final sql = File(
      'supabase/migrations/20261111001200_retire_public_event_deduplication_v1.sql',
    ).readAsStringSync();
    expect(sql, contains('pg_get_functiondef'));
    expect(
      sql,
      contains('public_event_deduplication_v1_still_has_dynamic_callers'),
    );
    expect(
      sql,
      contains(
        'drop function if exists public.get_public_event_deduplication_rows(boolean, date[])',
      ),
    );
    expect(
      sql,
      isNot(
        contains(
          'drop function if exists public.get_public_event_deduplication_rows_v2',
        ),
      ),
    );
  });
}
