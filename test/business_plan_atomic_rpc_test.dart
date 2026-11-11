import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('business plan creation is atomic and old game summary RPC retires', () {
    final sql = File(
      'supabase/migrations/20261111000900_business_plan_atomic_and_retired_game_rpc.sql',
    ).readAsStringSync();
    expect(
      sql,
      contains(
        'drop function if exists public.get_user_game_highest_passed_level(text, text)',
      ),
    );
    expect(sql, contains('create_business_plan_from_template'));
    expect(sql, contains('for v_template_section in'));
    expect(sql, contains('business_plan_template_question'));
    expect(sql, contains("raise exception 'plan_name_exists'"));
    expect(sql, contains('to authenticated, service_role'));
    expect(sql, contains("notify pgrst, 'reload schema'"));
  });

  test(
    'calendar batch raises recipient failures to roll back the transaction',
    () {
      final sql = File(
        'supabase/migrations/20261111000900_business_plan_atomic_and_retired_game_rpc.sql',
      ).readAsStringSync();
      expect(sql, contains('invite_calendar_viewers'));
      expect(sql, contains('foreach v_email in array p_invited_emails loop'));
      expect(sql, contains("raise exception '%'"));
    },
  );
}
