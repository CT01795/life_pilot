import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:life_pilot/event/model_event_item.dart';
import 'package:life_pilot/event/service_event.dart';
import 'package:life_pilot/utils/repository_cloud_gateway.dart';
import 'package:life_pilot/utils/repository_event_cloud_operations.dart';
import 'package:life_pilot/utils/supabase.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  late SupabaseClient client;
  late RepositoryEventCloudOperations repository;
  late List<http.Request> requests;
  dynamic response;
  var status = 200;
  setUp(() {
    response = null;
    status = 200;
    requests = [];
    client = SupabaseClient(
      'https://example.supabase.co',
      'public-key',
      httpClient: MockClient((request) async {
        requests.add(request);
        return http.Response(
          jsonEncode(response),
          status,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      }),
    );
    repository = RepositoryEventCloudOperations(
      gateway: RepositoryCloudGateway(client: client),
    );
  });
  tearDown(() => client.dispose());
  Future<dynamic> noBackend() async => throw StateError('Render must not run');

  for (final table in ['recommended_events', 'recommended_attractions']) {
    test(
      '$table cannot be deleted if approval history is unavailable',
      () async {
        supabase = client;
        status = 400;
        response = {'code': '42703', 'message': 'was_approved does not exist'};
        await expectLater(
          ServiceEvent().deleteEvent(
            currentAccount: 'owner@example.com',
            event: EventItem(id: 'event', name: 'Draft'),
            tableName: table,
          ),
          throwsA(isA<PostgrestException>()),
        );
        expect(requests.single.method, 'GET');
        expect(
          requests.single.url.queryParameters['select'],
          'is_approved,was_approved',
        );
      },
    );
  }

  for (final cached in [
    <String, dynamic>{'lat': 25, 'lng': 121},
    <String, dynamic>{},
  ]) {
    test(
      'geocode cache hit including negative result bypasses backend: $cached',
      () async {
        response = cached;
        expect(
          await repository.geocode(query: 'Taipei', backend: noBackend),
          cached,
        );
        expect(
          requests.single.url.path,
          '/rest/v1/rpc/life_pilot_cached_geocode',
        );
        expect(jsonDecode(requests.single.body), {'p_query': 'Taipei'});
      },
    );
  }
  test('geocode cache miss calls provider once', () async {
    response = null;
    var calls = 0;
    final result = await repository.geocode(
      query: 'Taipei',
      backend: () async {
        calls++;
        return {'lat': 25, 'lng': 121};
      },
    );
    expect(result['lat'], 25);
    expect(calls, 1);
  });
  test('fully cached bulk backfill does not call Render', () async {
    response = {
      'saved': 2,
      'remaining': 0,
      'next_offset': 0,
      'coverage_percent': 100,
      'needs_backend': false,
    };
    final service = ServiceEvent(cloudOperations: repository);
    final result = await service.backfillMapCoordinates(
      tableName: 'recommended_events',
    );
    expect(result.saved, 2);
    expect(result.coveragePercent, 100);
    expect(jsonDecode(requests.single.body), {
      'p_table_name': 'recommended_events',
      'p_offset': 0,
      'p_limit': 25,
    });
  });
  test(
    'mixed backfill adds cached saves but keeps final backend coverage',
    () async {
      response = {'saved': 2, 'needs_backend': true};
      var calls = 0;
      final result = await repository.backfillCoordinates(
        tableName: 'recommended_events',
        offset: 3,
        backend: () async {
          calls++;
          return {
            'saved': 1,
            'remaining': 4,
            'next_offset': 5,
            'coverage_percent': 60,
          };
        },
      );
      expect(calls, 1);
      expect(result, {
        'saved': 3,
        'remaining': 4,
        'next_offset': 5,
        'coverage_percent': 60,
      });
    },
  );
  test('public import forwards records through controlled RPC', () async {
    response = {
      'status': 'ok',
      'received_rows': 3,
      'inserted_rows': 1,
      'duplicate_rows': 2,
    };
    final rows = [
      {'id': 'new', 'name': 'Event', 'start_date': '2026-12-01'},
    ];
    final result = await repository.importPublicEvents(
      sourceUrl: 'https://strolltimes.com/test',
      events: rows,
    );
    expect(result.received, 3);
    expect(result.inserted, 1);
    expect(result.duplicates, 2);
    expect(
      requests.single.url.path,
      '/rest/v1/rpc/life_pilot_import_public_events',
    );
    expect(jsonDecode(requests.single.body), {
      'p_source_url': 'https://strolltimes.com/test',
      'p_events': rows,
    });
  });

  for (final code in ['PGRST202', '42501', 'P0001', '22023', '42P01']) {
    test(
      '$code never bypasses validation or permissions through backend',
      () async {
        response = {'code': code, 'message': 'Rejected'};
        status = 400;
        await expectLater(
          repository.geocode(query: 'x', backend: noBackend),
          throwsA(isA<PostgrestException>()),
        );
        await expectLater(
          repository.backfillCoordinates(
            tableName: 'recommended_events',
            offset: 0,
            backend: noBackend,
          ),
          throwsA(isA<PostgrestException>()),
        );
        await expectLater(
          repository.importPublicEvents(
            sourceUrl: 'https://evil.test',
            events: [{}],
          ),
          throwsA(isA<PostgrestException>()),
        );
      },
    );
  }
}
