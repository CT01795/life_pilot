import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:life_pilot/accounting/model_accounting_account.dart';
import 'package:life_pilot/accounting/repository_ledger_account_lookup.dart';
import 'package:life_pilot/accounting/service_accounting.dart';
import 'package:life_pilot/point_record/model_point_record_account.dart';
import 'package:life_pilot/point_record/service_point_record.dart';
import 'package:life_pilot/utils/supabase.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final points in [false, true]) {
    test(
      '${points ? 'points' : 'accounting'} event lookup uses one RPC',
      () async {
        late http.Request captured;
        final client = SupabaseClient(
          'https://example.supabase.co',
          'key',
          httpClient: MockClient((request) async {
            captured = request;
            return http.Response(
              jsonEncode(
                points
                    ? {
                        'id': 'account-id',
                        'account': 'Points',
                        'category': 'personal',
                        'points': 1234,
                      }
                    : {
                        'id': 'account-id',
                        'account': 'Cash',
                        'category': 'personal',
                        'balance': 123.45,
                        'main_currency': 'TWD',
                        'exchange_rate': 1,
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

        final result = points
            ? await ServicePointRecord().findAccountByEventId(
                eventId: 'event-id',
                user: 'one@example.com',
              )
            : await ServiceAccounting().findAccountByEventId(
                eventId: 'event-id',
                user: 'one@example.com',
              );

        expect(
          captured.url.path,
          '/rest/v1/rpc/get_my_ledger_account_by_event',
        );
        expect(jsonDecode(captured.body), {
          'p_kind': points ? 'points' : 'accounting',
          'p_event_id': 'event-id',
          'p_expected_email': 'one@example.com',
        });
        if (points) {
          expect((result as ModelPointRecordAccount).points, 1234);
        } else {
          expect((result as ModelAccountingAccount).balance, 123.45);
        }
      },
    );
  }

  test('ledger entry defaults uses one combined RPC', () async {
    late http.Request captured;
    final client = SupabaseClient(
      'https://example.supabase.co',
      'key',
      httpClient: MockClient((request) async {
        captured = request;
        return http.Response(
          jsonEncode({
            'accounting': {'value': -50, 'primary_category': 'food'},
            'points': {'value': 20, 'primary_category': 'exercise'},
          }),
          200,
          request: request,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    addTearDown(client.dispose);

    final result = await RepositoryLedgerAccountLookup(client).entryDefaults(
      expectedEmail: 'one@example.com',
      accountingAccountId: 'accounting-id',
      pointAccountId: 'point-id',
    );

    expect(captured.url.path, '/rest/v1/rpc/get_my_ledger_entry_defaults');
    expect(jsonDecode(captured.body), {
      'p_expected_email': 'one@example.com',
      'p_accounting_account_id': 'accounting-id',
      'p_point_account_id': 'point-id',
    });
    expect(result['accounting'], {'value': -50, 'primary_category': 'food'});
    expect(result['points'], {'value': 20, 'primary_category': 'exercise'});
  });
}
