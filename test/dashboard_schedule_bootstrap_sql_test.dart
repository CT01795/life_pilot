import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('dashboard bootstrap includes only visible compact schedule rows', () {
    final sql = File(
      'supabase/migrations/20261117000300_dashboard_schedule_bootstrap.sql',
    ).readAsStringSync();
    expect(sql, contains("'today_events', v_today_events"));
    expect(sql, contains("invitation.status = 'accepted'"));
    expect(sql, contains('selected.event_id = event.id'));
    expect(sql, contains("p_day_start + interval '3 days'"));
    expect(sql, contains('event.master_url'));
    expect(sql, isNot(contains('event.master_graph_url')));
  });

  test('dashboard review window does not change finance day boundaries', () {
    final sql = File(
      'supabase/migrations/20261127000100_dashboard_unfinished_schedule.sql',
    ).readAsStringSync();
    expect(sql, contains("p_day_start - interval '3 days'"));
    expect(sql, contains('lower(trim(event.account)) = v_email'));
    expect(sql, contains('coalesce(event.is_completed, false) is false'));
    expect(sql, contains('p_month_start, p_month_end, p_day_start, p_day_end'));
    expect(sql, isNot(contains('event.master_graph_url')));
  });
}
