import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:life_pilot/accounting/model_accounting_account.dart';
import 'package:life_pilot/accounting/service_accounting.dart';
import 'package:life_pilot/point_record/model_point_record_account.dart';
import 'package:life_pilot/point_record/service_point_record.dart';
import 'package:life_pilot/utils/supabase.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final points in [false, true]) {
    group(points ? 'points' : 'accounting', () {
      late SupabaseClient client;
      late List<Uri> requests;
      late List<Map<String, dynamic>> response;
      var failed = false;
      Future<Object?> read({String id = 'selected'}) => points
          ? ServicePointRecord().fetchAccountById(
              user: 'one@example.com',
              accountId: id,
            )
          : ServiceAccounting().fetchAccountById(
              user: 'one@example.com',
              accountId: id,
            );
      setUp(() {
        requests = [];
        failed = false;
        response = [
          {
            'id': 'selected',
            'account': 'Selected',
            'category': 'personal',
            'balance': 23.4567,
            'main_currency': 'USD',
            'exchange_rate': 32.1,
            'points': 1234,
          },
        ];
        client = SupabaseClient(
          'https://example.supabase.co',
          'test-key',
          httpClient: MockClient((request) async {
            requests.add(request.url);
            return http.Response(
              jsonEncode(
                failed ? {'message': 'unavailable', 'code': 'XX000'} : response,
              ),
              failed ? 500 : 200,
              headers: {'content-type': 'application/json'},
              request: request,
            );
          }),
        );
        supabase = client;
      });
      tearDown(() => client.dispose());

      test(
        'image-free account lists ignore image payloads and keep numeric fields',
        () async {
          response.single['master_graph_url'] = 'malformed-base64';
          if (points) {
            final accounts = await ServicePointRecord().fetchAccounts(
              user: 'one@example.com',
              includeGraph: false,
            );
            expect(accounts.single.points, 1234);
            expect(accounts.single.masterGraphUrl, null);
          } else {
            final accounts = await ServiceAccounting().fetchAccounts(
              user: 'one@example.com',
              includeGraph: false,
            );
            expect(accounts.single.balance, 23.4567);
            expect(accounts.single.currency, 'USD');
            expect(accounts.single.masterGraphUrl, null);
          }
          expect(requests, hasLength(1));
          expect(
            requests.single.queryParameters['select'],
            isNot(contains('master_graph_url')),
          );
        },
      );

      test('image-inclusive account lists still decode image bytes', () async {
        response.single['master_graph_url'] = base64Encode([1, 2, 3]);
        if (points) {
          final accounts = await ServicePointRecord().fetchAccounts(
            user: 'one@example.com',
          );
          expect(accounts.single.masterGraphUrl, [1, 2, 3]);
        } else {
          final accounts = await ServiceAccounting().fetchAccounts(
            user: 'one@example.com',
          );
          expect(accounts.single.masterGraphUrl, [1, 2, 3]);
        }
        expect(requests, hasLength(1));
        expect(requests.single.queryParameters['select'], '*');
      });

      test(
        'one scoped request retrieves only the selected account without images',
        () async {
          final result = await read();
          final request = requests.single;
          expect(
            request.path,
            '/rest/v1/${points ? 'point_record_account' : 'accounting_account'}',
          );
          expect(request.queryParameters['id'], 'eq.selected');
          expect(request.queryParameters['created_by'], 'eq.one@example.com');
          expect(request.queryParameters['is_valid'], 'eq.true');
          expect(
            request.queryParameters['select'],
            isNot(contains('master_graph_url')),
          );
          if (points) {
            expect((result as ModelPointRecordAccount).points, 1234);
            expect(result.masterGraphUrl, null);
          } else {
            final account = result as ModelAccountingAccount;
            expect(account.balance, 23.4567);
            expect(account.currency, 'USD');
            expect(account.exchangeRate, 32.1);
            expect(account.masterGraphUrl, null);
          }
        },
      );
      test(
        'missing or RLS-hidden account returns null without a list fallback',
        () async {
          response = [];
          expect(await read(), null);
          expect(requests, hasLength(1));
        },
      );
      test('empty IDs issue no request', () async {
        expect(await read(id: ''), null);
        expect(requests, isEmpty);
      });
      test(
        'query errors stay visible to the caller instead of becoming an account',
        () async {
          failed = true;
          await expectLater(read(), throwsA(isA<PostgrestException>()));
          expect(requests, hasLength(1));
        },
      );
    });
  }
}
