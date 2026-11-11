import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:life_pilot/event/repository_import_deletion_keys.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test(
    'import reads only batch-day identity columns from both sources',
    () async {
      final requests = <Uri>[];
      final day = DateTime(2026, 11, 3);
      final client = SupabaseClient(
        'https://example.supabase.co',
        'test-key',
        httpClient: MockClient((request) async {
          requests.add(request.url);
          return http.Response(
            jsonEncode([
              {
                'id': 'event-1',
                'name': 'Sample',
                'city': '台北',
                'location': 'Park',
                'start_date': day.toUtc().toIso8601String(),
                'start_time': '09:00',
              },
            ]),
            200,
            request: request,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      addTearDown(client.dispose);
      final repository = RepositoryImportDeletionKeys(client);
      expect(await repository.readNewDays([]), isEmpty);
      expect(requests, isEmpty);
      final existing = await repository.readNewDays([day, day]);
      expect(existing, hasLength(3));
      expect(await repository.readNewDays([day]), isEmpty);
      expect(requests.map((uri) => uri.path.split('/').last), [
        'get_public_event_deduplication_rows_v2',
      ]);
      for (final uri in requests) {
        expect(uri.queryParameters, isEmpty);
      }
    },
  );
}
