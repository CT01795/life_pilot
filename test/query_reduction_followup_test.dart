import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:life_pilot/event/service_event.dart';
import 'package:life_pilot/utils/supabase.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test(
    'memory window returns rows and continuation metadata in one RPC',
    () async {
      late http.Request captured;
      final client = SupabaseClient(
        'https://example.supabase.co',
        'key',
        httpClient: MockClient((request) async {
          captured = request;
          return http.Response(
            jsonEncode({
              'events': [
                {
                  'id': 'memory-1',
                  'name': 'Memory',
                  'start_date': '2026-10-01T00:00:00Z',
                },
              ],
              'has_page_more': false,
              'has_more': true,
              'window_start': '2026-10-01',
              'window_end': '2026-10-30',
              'next_date': '2026-09-20',
            }),
            200,
            request: request,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      supabase = client;
      addTearDown(client.dispose);

      final result = await ServiceEvent().getMemoryWindow(
        from: DateTime(2026, 10, 1),
        to: DateTime(2026, 10, 30),
        limit: 12,
        expandFallback: true,
      );

      expect(captured.url.path, '/rest/v1/rpc/get_my_memory_window');
      expect(jsonDecode(captured.body), {
        'p_from': '2026-10-01',
        'p_to': '2026-10-30',
        'p_limit': 12,
        'p_offset': 0,
        'p_expand_fallback': true,
      });
      expect(result.events.single.id, 'memory-1');
      expect(result.hasMore, isTrue);
      expect(result.nextDate, DateTime(2026, 9, 20));
    },
  );

  test('query reduction migration protects and combines all new reads', () {
    final sql = File(
      'supabase/migrations/20261118000400_query_reduction_followup.sql',
    ).readAsStringSync();

    expect(sql, contains('get_my_memory_window'));
    expect(
      sql,
      contains("'has_more', v_count > v_limit or v_next is not null"),
    );
    expect(sql, contains('get_admin_question_hint'));
    expect(
      sql,
      contains(
        "p_table_name not in ('game_grammar', 'game_sentence', 'game_translation')",
      ),
    );
    expect(sql, contains('get_missing_public_event_sources'));
    expect(sql, contains('unnest(coalesce(p_urls'));
    expect(sql, contains('dashboard_account_id_backfill_incomplete'));
    expect(
      sql,
      contains('drop function if exists public.get_my_memory_initial_window'),
    );
    expect(sql, contains("notify pgrst, 'reload schema'"));

    final paginationSql = File(
      'supabase/migrations/20261118000700_memory_window_pagination.sql',
    ).readAsStringSync();
    expect(paginationSql, contains('p_offset integer default 0'));
    expect(paginationSql, contains('offset v_offset'));
  });

  test('app uses combined reads and no name-only dashboard fallback', () {
    final game = File('lib/game/service_game.dart').readAsStringSync();
    final publicEvents = File(
      'lib/event/service_event_public.dart',
    ).readAsStringSync();
    final home = File(
      'lib/pages/home/widgets/dashboard/home_quick_record_navigation.dart',
    ).readAsStringSync();

    expect(game, contains("'get_admin_question_hint'"));
    expect(publicEvents, contains("'get_missing_public_event_sources'"));
    expect(publicEvents, isNot(contains('checkIfUrlExists')));
    expect(home, isNot(contains('searchQuery: accountName')));
    expect(home, isNot(contains('service.fetchAccounts')));
  });
}
