import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:life_pilot/accounting/service_accounting.dart';
import 'package:life_pilot/point_record/service_point_record.dart';
import 'package:life_pilot/utils/supabase.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('cloud ledger account creation uses one atomic RPC', () {
    final accounting = File(
      'lib/accounting/service_accounting.dart',
    ).readAsStringSync();
    final points = File(
      'lib/point_record/service_point_record.dart',
    ).readAsStringSync();

    for (final source in [accounting, points]) {
      expect(source, contains("'create_or_restore_my_ledger_account'"));
      expect(source, isNot(contains(".select('id,is_valid')")));
    }
    expect(accounting, contains("'p_kind': 'accounting'"));
    expect(points, contains("'p_kind': 'points'"));
  });

  test('atomic ledger account RPC is scoped and protected', () {
    final sql = File(
      'supabase/migrations/20261118000300_ledger_account_create_or_restore.sql',
    ).readAsStringSync();

    expect(sql, contains('auth.uid() is null'));
    expect(sql, contains('lower(trim(a.created_by)) = v_email'));
    expect(sql, contains("p_kind not in ('accounting', 'points')"));
    expect(sql, contains("raise exception 'account_already_exists'"));
    expect(sql, contains('pg_advisory_xact_lock'));
    expect(sql, contains('for update'));
    expect(sql, contains('to authenticated, service_role'));
    expect(sql, contains("notify pgrst, 'reload schema'"));
  });

  for (final points in [false, true]) {
    test(
      '${points ? 'points' : 'accounting'} creation makes one request',
      () async {
        final requests = <http.Request>[];
        final client = SupabaseClient(
          'https://example.supabase.co',
          'key',
          httpClient: MockClient((request) async {
            requests.add(request);
            return http.Response(
              jsonEncode(
                points
                    ? {
                        'id': '00000000-0000-0000-0000-000000000001',
                        'account': 'Rewards',
                        'category': 'personal',
                        'points': 0,
                      }
                    : {
                        'id': '00000000-0000-0000-0000-000000000001',
                        'account': 'Cash',
                        'category': 'personal',
                        'balance': 0,
                        'main_currency': 'TWD',
                        'exchange_rate': null,
                      },
              ),
              200,
              request: request,
              headers: {'content-type': 'application/json'},
            );
          }),
        );
        supabase = client;
        addTearDown(client.dispose);

        if (points) {
          await ServicePointRecord().createAccount(
            name: 'Rewards',
            user: 'one@example.com',
            currency: null,
            category: 'personal',
            eventId: '00000000-0000-0000-0000-000000000001',
          );
        } else {
          await ServiceAccounting().createAccount(
            name: 'Cash',
            user: 'one@example.com',
            currency: 'TWD',
            category: 'personal',
            eventId: '00000000-0000-0000-0000-000000000001',
          );
        }

        expect(requests, hasLength(1));
        expect(
          requests.single.url.path,
          '/rest/v1/rpc/create_or_restore_my_ledger_account',
        );
        expect(jsonDecode(requests.single.body), {
          'p_kind': points ? 'points' : 'accounting',
          'p_account_id': '00000000-0000-0000-0000-000000000001',
          'p_name': points ? 'Rewards' : 'Cash',
          'p_category': 'personal',
          'p_currency': points ? null : 'TWD',
        });
      },
    );
  }
}
