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
}
