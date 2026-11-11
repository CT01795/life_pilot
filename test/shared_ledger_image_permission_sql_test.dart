import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('overview resolves image permission without a broad table grant', () {
    final sql = File(
      'supabase/migrations/'
      '20261111000100_fix_shared_ledger_overview_image_permission.sql',
    ).readAsStringSync();

    expect(
      sql,
      contains(
        'image_allowed := public.can_change_shared_ledger_image(share_id)',
      ),
    );
    expect(
      sql,
      contains(
        'revoke select on table public.ledger_read_shares from authenticated',
      ),
    );
    expect(
      sql,
      isNot(contains('select s.allow_image_changes into image_allowed')),
    );
  });
}
