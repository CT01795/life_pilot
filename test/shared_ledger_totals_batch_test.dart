import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:life_pilot/accounting/service_ledger_sharing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final legacy in [false, true]) {
    test('batches simultaneous reads (legacy: $legacy)', () async {
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
      final results = await Future.wait([
        ServiceLedgerSharing(client: client).totals('a', now: now),
        ServiceLedgerSharing(client: client).totals('b', now: now),
      ]);
      expect(results.map((r) => r['total']), [10, 20]);
      expect(requests, [
        'get_my_shared_ledger_totals_batch',
        if (legacy) ...[
          'get_my_shared_ledger_totals',
          'get_my_shared_ledger_totals',
        ],
      ]);
      requests.clear();
      final refreshed = await Future.wait([
        ServiceLedgerSharing(client: client).totals('a', now: now),
        ServiceLedgerSharing(client: client).totals('b', now: now),
      ]);
      expect(refreshed.map((r) => r['total']), [10, 20]);
      expect(
        requests,
        legacy
            ? ['get_my_shared_ledger_totals', 'get_my_shared_ledger_totals']
            : ['get_my_shared_ledger_totals_batch'],
      );
    });
  }
}
