import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:life_pilot/local_storage/local_data_store.dart';
import 'package:life_pilot/record_statistics/model_record_statistics.dart';
import 'package:life_pilot/record_statistics/service_record_statistics.dart';
import 'package:life_pilot/utils/api.dart' as api;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SupabaseClient client;
  late List<Uri> requests;
  var active = true;
  var expireOnResponse = false;
  final now = DateTime(2026, 10, 21);
  setUp(() async {
    requests = [];
    active = true;
    expireOnResponse = false;
    client = SupabaseClient(
      'https://example.supabase.co',
      'test-key',
      httpClient: MockClient((request) async {
        requests.add(request.url);
        if (expireOnResponse) active = false;
        final offset = int.parse(request.url.queryParameters['offset'] ?? '0');
        final source = List.generate(
          3,
          (index) => {
            'id': '$index',
            'date': now.toIso8601String(),
            'value': index,
            'currency': 'TWD',
          },
        );
        return http.Response(
          jsonEncode(source.skip(offset).take(2).toList()),
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      }),
    );
    api.supabase = client;
    await client.auth.setInitialSession(
      jsonEncode({
        'access_token': 'test-token',
        'token_type': 'bearer',
        'user': {
          'id': 'owner',
          'email': 'one@example.com',
          'app_metadata': {},
          'user_metadata': {},
          'aud': 'authenticated',
          'created_at': '2026-01-01T00:00:00Z',
        },
      }),
    );
  });
  tearDown(() => client.dispose());

  Future<List<Map<String, dynamic>>> read(
    RecordStatisticsKind kind,
    bool history,
  ) => ServiceRecordStatistics().read(
    owner: 'one@example.com',
    storage: DataStorageLocation.cloud,
    accountId: 'a',
    kind: kind,
    now: now,
    currency: 'TWD',
    history: history,
    shouldContinue: () => active,
  );

  for (final kind in RecordStatisticsKind.values) {
    test('$kind inactive query starts no HTTP request', () async {
      active = false;
      expect(await read(kind, true), isEmpty);
      expect(requests, isEmpty);
    });
    for (final history in [false, true]) {
      test(
        '$kind history=$history stops after the expired in-flight response',
        () async {
          expireOnResponse = true;
          expect(await read(kind, history), isEmpty);
          expect(requests.length, 1);
        },
      );
      test(
        '$kind history=$history retains all capped pages and original filters',
        () async {
          final rows = await read(kind, history);
          expect(rows.map((row) => row['id']), ['0', '1', '2']);
          expect(requests.map((uri) => uri.queryParameters['offset']), [
            '0',
            '2',
            '3',
          ]);
          for (final request in requests) {
            expect(request.queryParameters['account_id'], 'eq.a');
            expect(
              request.queryParameters['order'],
              'date.desc.nullslast,id.desc.nullslast',
            );
            expect(request.queryParameters.containsKey('date'), !history);
            if (kind == RecordStatisticsKind.accounting) {
              expect(request.path, endsWith('/accounting_detail'));
              expect(request.queryParameters['currency'], 'eq.TWD');
            } else {
              expect(request.path, endsWith('/point_record_detail'));
              expect(request.queryParameters.containsKey('currency'), false);
            }
          }
        },
      );
    }
  }
}
