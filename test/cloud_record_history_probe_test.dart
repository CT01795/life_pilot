import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:life_pilot/record_statistics/repository_cloud_record_history.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('history window returns rows, total and next cursor together', () async {
    final requests = <http.Request>[];
    var missing = false;
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
          jsonEncode({
            'rows': [
              {'id': 'one'},
            ],
            'total': 123.5,
            'next_before': '2026-09-15T00:00:00Z',
            'next_date': '2026-09-12T00:00:00Z',
          }),
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

    Future<CloudRecordHistoryWindow> read() => repository.window(
      client,
      table: 'accounting_detail',
      kind: 'accounting',
      accountId: 'a',
      type: 'balance',
      from: DateTime.utc(2026, 10),
      until: DateTime.utc(2026, 11),
      includeReserved: true,
      includeLatest: true,
    );

    final simultaneous = await Future.wait([read(), read()]);
    expect(requests, hasLength(1));
    expect(simultaneous.first.rows.single['id'], 'one');
    expect(simultaneous.first.total, 123.5);
    expect(simultaneous.first.nextBefore.toUtc(), DateTime.utc(2026, 9, 15));
    expect(simultaneous.first.nextDate?.toUtc(), DateTime.utc(2026, 9, 12));

    repository.invalidate();
    await read();
    expect(requests, hasLength(2));

    missing = true;
    repository.invalidate();
    await expectLater(
      read(),
      throwsA(
        isA<PostgrestException>().having((e) => e.code, 'code', 'PGRST202'),
      ),
    );
    expect(
      requests.last.url.path,
      endsWith('/get_my_ledger_history_window_v2'),
    );
  });
}
