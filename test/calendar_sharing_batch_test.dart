import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:life_pilot/calendar/service_calendar_sharing.dart';
import 'package:life_pilot/local_storage/local_data_store.dart';
import 'package:life_pilot/utils/api.dart' as api;

void main() {
  late Database database;
  late LocalDataStore store;
  late SupabaseClient client;
  late ServiceCalendarSharing service;
  late List<Map<String, dynamic>> requests;
  void Function()? onRequest;
  var failure = false;
  setUp(() async {
    database = await databaseFactoryMemory.openDatabase('sharing-batch');
    store = LocalDataStore.withDatabase(database);
    await store.setPreferredLocation(
      'one@example.com',
      DataStorageLocation.cloud,
    );
    requests = [];
    onRequest = null;
    failure = false;
    client = SupabaseClient(
      'https://example.supabase.co',
      'test-key',
      httpClient: MockClient((request) async {
        requests.add(
          Map<String, dynamic>.from(jsonDecode(request.body) as Map),
        );
        onRequest?.call();
        return http.Response(
          jsonEncode(
            failure
                ? {'code': 'P0001', 'message': 'DUPLICATE_INVITATION'}
                : {'ok': true},
          ),
          failure ? 400 : 200,
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
    service = ServiceCalendarSharing(localStore: store);
  });
  tearDown(() async {
    await client.dispose();
    await database.close();
  });
  test(
    'event IDs are enumerated once and reused across all recipients',
    () async {
      var passes = 0;
      Iterable<String> ids() sync* {
        if (++passes > 1) throw StateError('Repeated event selection scan');
        yield 'a';
        yield 'b';
      }

      await service.inviteAll([
        ' two@example.com ',
        'three@example.com',
      ], ids());
      expect(passes, 1);
      expect(requests.map((row) => row['p_invited_email']), [
        'two@example.com',
        'three@example.com',
      ]);
      expect(requests.map((row) => row['p_event_ids']), [
        ['a', 'b'],
        ['a', 'b'],
      ]);
    },
  );
  test(
    'caller mutations during a request do not alter the remaining batch',
    () async {
      final recipients = ['two@example.com', 'three@example.com'];
      final ids = ['a', 'b'];
      onRequest = () {
        recipients.clear();
        ids.clear();
      };
      await service.inviteAll(recipients, ids);
      expect(requests, hasLength(2));
      expect(requests.last['p_invited_email'], 'three@example.com');
      expect(requests.last['p_event_ids'], ['a', 'b']);
    },
  );
  test(
    'server failure retains translation and stops subsequent recipients',
    () async {
      failure = true;
      await expectLater(
        service.inviteAll(['two@example.com', 'three@example.com'], ['a']),
        throwsA(
          isA<CalendarSharingFailure>().having(
            (e) => e.code,
            'code',
            'duplicate',
          ),
        ),
      );
      expect(requests, hasLength(1));
    },
  );
  test('local mode is still rejected before sending requests', () async {
    await store.setPreferredLocation(
      'one@example.com',
      DataStorageLocation.local,
    );
    await expectLater(
      service.inviteAll(['two@example.com'], ['a']),
      throwsStateError,
    );
    expect(requests, isEmpty);
  });
  test('empty recipients do not traverse event IDs or send requests', () async {
    Iterable<String> ids() sync* {
      throw StateError('No recipients');
    }

    await service.inviteAll([], ids());
    expect(requests, isEmpty);
  });
}
