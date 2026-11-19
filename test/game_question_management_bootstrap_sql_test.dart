import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('question management bootstrap reuses deployed page and group RPCs', () {
    final sql = File(
      'supabase/migrations/20261119000200_game_question_management_bootstrap.sql',
    ).readAsStringSync();

    expect(sql, contains('get_my_question_management_page'));
    expect(sql, contains('get_my_questions_page'));
    expect(sql, contains('get_my_question_groups_for_management'));
    expect(sql, contains('with ordinality'));
    expect(sql, contains("'rows'"));
    expect(sql, contains("'groups'"));
    expect(sql, contains('from public, anon'));
    expect(sql, contains('to authenticated, service_role'));
  });
}
