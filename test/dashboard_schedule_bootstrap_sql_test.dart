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
}
