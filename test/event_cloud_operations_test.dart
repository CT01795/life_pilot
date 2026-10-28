import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:life_pilot/event/model_event_item.dart';
import 'package:life_pilot/event/service_event.dart';
import 'package:life_pilot/utils/repository_cloud_gateway.dart';
import 'package:life_pilot/utils/repository_event_cloud_operations.dart';
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
  test('cache miss and undeployed RPC each call backend once', () async {
    for (final deployed in [true, false]) {
      status = deployed ? 200 : 404;
      response = deployed ? null : {'code': 'PGRST202', 'message': 'Not found'};
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
    }
  });
  test('map coordinate lookup passes only table and event ID', () async {
    response = {'lat': 25, 'lng': 121};
    expect(
      await repository.mapCoordinates(
        tableName: 'calendar_events',
        eventId: 'event',
        backend: noBackend,
      ),
      response,
    );
    expect(jsonDecode(requests.single.body), {
      'p_table_name': 'calendar_events',
      'p_event_id': 'event',
    });
  });
  test('cached map negative result does not request provider again', () async {
    response = {};
    expect(
      await repository.mapCoordinates(
        tableName: 'calendar_events',
        eventId: 'event',
        backend: noBackend,
      ),
      isEmpty,
    );
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
    response = {'status': 'ok', 'inserted_rows': 1};
    final rows = [
      {'id': 'new', 'name': 'Event', 'start_date': '2026-12-01'},
    ];
    expect(
      await repository.importPublicEvents(
        sourceUrl: 'https://strolltimes.com/test',
        events: rows,
        backend: noBackend,
      ),
      response,
    );
    expect(
      requests.single.url.path,
      '/rest/v1/rpc/life_pilot_import_public_events',
    );
    expect(jsonDecode(requests.single.body), {
      'p_source_url': 'https://strolltimes.com/test',
      'p_events': rows,
    });
  });
  test('undeployed import RPC retains original import handler', () async {
    response = {'code': 'PGRST202', 'message': 'missing'};
    status = 404;
    var calls = 0;
    await repository.importPublicEvents(
      sourceUrl: 'https://strolltimes.com/test',
      events: [
        {'id': 'new'},
      ],
      backend: () async {
        calls++;
        return {'status': 'ok'};
      },
    );
    expect(calls, 1);
  });
  for (final code in ['42501', 'P0001', '22023', '42P01']) {
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
          repository.mapCoordinates(
            tableName: 'memory_trace',
            eventId: 'x',
            backend: noBackend,
          ),
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
            backend: noBackend,
          ),
          throwsA(isA<PostgrestException>()),
        );
      },
    );
  }
  test(
    'ServiceEvent uses cached map coordinates without backend or client-supplied values',
    () async {
      response = {'lat': 25, 'lng': 121};
      final service = ServiceEvent(cloudOperations: repository);
      final event = EventItem(
        id: 'event',
        name: 'Event',
        city: 'Taipei',
        location: 'Station',
      );
      final updated = await service.ensureMapCoordinates(
        tableName: 'calendar_events',
        event: event,
      );
      expect(identical(updated, event), isTrue);
      expect(event.mapLat, 25);
      expect(event.mapLng, 121);
    },
  );
}
