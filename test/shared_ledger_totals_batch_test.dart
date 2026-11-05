import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:life_pilot/accounting/service_ledger_sharing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'missing overview and proposal RPCs fail without cross-query fallback',
    () async {
      final calls = <String>[];
      final client = SupabaseClient(
        'https://example.supabase.co',
        'key',
        httpClient: MockClient((request) async {
          calls.add(request.url.pathSegments.last);
          return http.Response(
            '{"code":"PGRST202","message":"missing"}',
            404,
            request: request,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      addTearDown(client.dispose);
      await client.auth.setInitialSession(
        jsonEncode({
          'access_token': 'token-test',
          'token_type': 'bearer',
          'user': {
            'id': 'test',
            'aud': 'authenticated',
            'created_at': '2026-01-01T00:00:00Z',
          },
        }),
      );
      final sharing = ServiceLedgerSharing(client: client);
      final missing = throwsA(
        isA<PostgrestException>().having((e) => e.code, 'code', 'PGRST202'),
      );
      await expectLater(
        sharing.pendingCounts(LedgerKind.accounting, accountId: 'a'),
        missing,
      );
      await expectLater(sharing.pendingCounts(LedgerKind.points), missing);
      await expectLater(
        sharing.overviewPage(
          LedgerKind.accounting,
          0,
          limit: 11,
          visibleLimit: 10,
        ),
        missing,
      );
      expect(calls, [
        'get_my_ledger_account_pending_count',
        'get_my_ledger_pending_counts',
        'list_my_shared_ledger_overview_window',
      ]);
    },
  );
  test('dashboard uses only the combined preview endpoint', () async {
    final requests = <http.Request>[];
    var missing = false;
    final client = SupabaseClient(
      'https://example.supabase.co',
      'key',
      httpClient: MockClient((request) async {
        requests.add(request);
        return http.Response(
          missing
              ? '{"code":"PGRST202","message":"missing"}'
              : request.url.path.endsWith('_by_kind')
              ? '[]'
              : '{"totals":{"total":-50},"entries":[{"entry":{"description":"Lunch","value":-50,"currency":"TWD"}}]}',
          missing ? 404 : 200,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      }),
    );
    addTearDown(client.dispose);
    await client.auth.setInitialSession(
      jsonEncode({
        'access_token': 'token-test',
        'token_type': 'bearer',
        'user': {
          'id': 'test',
          'aud': 'authenticated',
          'created_at': '2026-01-01T00:00:00Z',
        },
      }),
    );
    final sharing = ServiceLedgerSharing(client: client);
    final snapshot = await sharing.homePreview('a');
    expect(snapshot.totals['total'], -50);
    expect(snapshot.entries.single['entry'], containsPair('value', -50));
    missing = true;
    await expectLater(
      sharing.homePreview('a'),
      throwsA(
        isA<PostgrestException>().having((e) => e.code, 'code', 'PGRST202'),
      ),
    );
    expect(requests.map((r) => r.url.pathSegments.last), [
      'get_my_shared_ledger_home_preview',
      'get_my_shared_ledger_home_preview',
    ]);
    requests.clear();
    missing = false;
    for (final kind in LedgerKind.values) {
      await sharing.receivedKindPage(kind, 0);
      await sharing.receivedKindPage(kind, 10);
    }
    expect(requests.map((r) => jsonDecode(r.body)['p_kind']), [
      'accounting',
      'accounting',
      'points',
      'points',
    ]);
    expect(requests.map((r) => jsonDecode(r.body)['p_offset']), [0, 10, 0, 10]);
    requests.clear();
    missing = true;
    final notDeployed = throwsA(
      isA<PostgrestException>().having((e) => e.code, 'code', 'PGRST202'),
    );
    await expectLater(
      sharing.receivedKindPage(LedgerKind.accounting, 0),
      notDeployed,
    );
    final detail = sharing.detailFirstPage('a');
    await expectLater(
      Future.wait<Object>([detail.canPropose, detail.totals, detail.entries]),
      notDeployed,
    );
    expect(requests.map((r) => r.url.pathSegments.last), [
      'list_my_shared_ledgers_by_kind',
      'get_my_shared_ledger_detail_first_page',
    ]);
  });
  for (final legacy in [false, true]) {
    test(
      'batches simultaneous reads without fallback (missing: $legacy)',
      () async {
        final requests = <String>[];
        final client = SupabaseClient(
          'https://example.supabase.co',
          'key',
          httpClient: MockClient((request) async {
            final rpc = request.url.pathSegments.last;
            requests.add(rpc);
            final body = jsonDecode(request.body) as Map;
            final batch = rpc.endsWith('_batch');
            final missing = batch && legacy;
            final Object response = missing
                ? {'code': 'PGRST202', 'message': 'missing'}
                : batch
                ? {
                    for (final id in body['p_share_ids'] as List)
                      id: {'total': id == 'a' ? 10 : 20},
                  }
                : {'total': body['p_share_id'] == 'a' ? 10 : 20};
            return http.Response(
              jsonEncode(response),
              missing ? 404 : 200,
              headers: {'content-type': 'application/json'},
              request: request,
            );
          }),
        );
        addTearDown(client.dispose);
        await client.auth.setInitialSession(
          jsonEncode({
            'access_token': 'token-test',
            'token_type': 'bearer',
            'user': {
              'id': 'test',
              'aud': 'authenticated',
              'created_at': '2026-01-01T00:00:00Z',
            },
          }),
        );
        final now = DateTime(2026, 11, 3);
        final sharing = ServiceLedgerSharing(client: client);
        Future<List<Map<String, dynamic>>> batch() => Future.wait([
          sharing.totals('a', now: now),
          sharing.totals('b', now: now),
        ]);
        if (legacy) {
          await expectLater(
            batch(),
            throwsA(
              isA<PostgrestException>().having(
                (e) => e.code,
                'code',
                'PGRST202',
              ),
            ),
          );
        } else {
          expect((await batch()).map((r) => r['total']), [10, 20]);
        }
        expect(requests, ['get_my_shared_ledger_totals_batch']);
        requests.clear();
        expect((await sharing.totals('a', now: now))['total'], 10);
        expect(requests, ['get_my_shared_ledger_totals']);
      },
    );
  }
}
