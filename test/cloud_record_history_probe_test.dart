import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:life_pilot/record_statistics/repository_cloud_record_history.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('history probe reuses only a matching boundary once', () async {
    final requests = <http.Request>[];
    var missing = false;
    String? nextDate = '2026-09-12T00:00:00Z';
    final client = SupabaseClient(
      'https://example.supabase.co',
      'test-key',
      httpClient: MockClient((request) async {
        requests.add(request);
        if (missing) {
          return http.Response(
            '{"code":"PGRST202","message":"missing"}',
            404,
            request: request,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response(
          request.url.path.endsWith('/get_my_ledger_history_window_v2') &&
                  jsonDecode(request.body)['p_include_latest'] == true
              ? '{"rows":[{"id":"fallback"}],"next_before":"2026-09-15T00:00:00Z","next_date":"2026-09-12T00:00:00Z"}'
              : request.url.path.endsWith('/get_my_ledger_history_window_v2')
              ? jsonEncode({
                  'rows': [
                    {'id': 'one'},
                  ],
                  'next_date': nextDate,
                })
              : '[{"date":"2026-09-12T00:00:00Z"}]',
          200,
          request: request,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    addTearDown(client.dispose);
    await client.auth.setInitialSession(
      jsonEncode({
        'access_token': 'test-token',
        'token_type': 'bearer',
        'user': {
          'id': 'test',
          'aud': 'authenticated',
          'created_at': '2026-01-01T00:00:00Z',
        },
      }),
    );
    final repository = RepositoryCloudRecordHistory();
    Future<DateTime?> read({
      bool probe = false,
      String id = 'a',
      DateTime? before,
    }) => repository.latestBefore(
      client,
      table: 'accounting_detail',
      accountId: id,
      type: 'balance',
      before: before ?? DateTime.utc(2026, 10),
      rememberForNextPage: probe,
    );
    final date = await read(probe: true);
    expect(await read(), date);
    expect(requests, hasLength(1));
    expect(requests.single.url.queryParameters['select'], 'date');
    await read();
    expect(requests, hasLength(2));
    await read(probe: true);
    await read(id: 'b');
    expect(requests, hasLength(4));
    await read(probe: true);
    repository.invalidate();
    await read();
    expect(requests, hasLength(6));
    final concurrent = await Future.wait([read(), read()]);
    expect(concurrent, [date, date]);
    expect(requests, hasLength(7));
    Future<CloudRecordHistoryWindow?> window({bool includeLatest = false}) =>
        repository.window(
          client,
          table: 'accounting_detail',
          kind: 'accounting',
          accountId: 'a',
          type: 'balance',
          from: DateTime.utc(2026, 10),
          until: DateTime.utc(2026, 11),
          includeReserved: true,
          includeLatest: includeLatest,
        );
    final simultaneousWindows = await Future.wait([window(), window()]);
    expect(simultaneousWindows.map((page) => page?.rows.single['id']), [
      'one',
      'one',
    ]);
    expect(await read(probe: true), date);
    expect(await read(), date);
    expect(requests, hasLength(8));
    nextDate = null;
    await window();
    expect(await read(probe: true), isNull);
    expect(requests, hasLength(9));
    expect((await window(includeLatest: true))?.rows.single['id'], 'fallback');
    expect(await read(probe: true, before: DateTime.utc(2026, 9, 15)), date);
    expect(requests, hasLength(10));
    missing = true;
    await expectLater(
      window(),
      throwsA(
        isA<PostgrestException>().having((e) => e.code, 'code', 'PGRST202'),
      ),
    );
    expect(requests, hasLength(11));
    expect(
      requests.last.url.path,
      endsWith('/get_my_ledger_history_window_v2'),
    );
  });
}
