import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:life_pilot/event/model_event_item.dart';
import 'package:life_pilot/event/service_event.dart';
import 'package:life_pilot/local_storage/local_data_store.dart';
import 'package:life_pilot/utils/api.dart' as api;
import 'package:life_pilot/utils/const.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SupabaseClient client;
  late List<Map<String, dynamic>> response;
  late List<Uri> requests;
  setUp(() {
    requests = [];
    response = [
      {
        'id': 'old',
        'name': 'Old memory',
        'start_date': '2026-01-01T08:00:00Z',
        'country': 'TW',
      },
    ];
    client = SupabaseClient(
      'https://example.supabase.co',
      'test-key',
      httpClient: MockClient((request) async {
        requests.add(request.url);
        var returnedRows = response;
        if (request.method == 'POST' && request.url.path.contains('/rpc/')) {
          final payload = (jsonDecode(request.body) as Map)['payload'] as Map;
          final limit = payload['inputlimit'] as int?;
          final offset = payload['inputoffset'] as int? ?? 0;
          if (limit != null) {
            returnedRows = response.skip(offset).take(limit).toList();
          }
        }
        return http.Response(
          jsonEncode(returnedRows),
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      }),
    );
    api.supabase = client;
  });
  tearDown(() => client.dispose());

  test('memory publishes six complete photo records before the rest', () async {
    response = List.generate(
      24,
      (index) => {
        'id': '$index',
        'name': 'Memory $index',
        'master_graph_url': 'original-photo-$index',
        'start_date': '2026-10-01T08:00:00Z',
      },
    );
    final snapshots = <List<EventItem>>[];
    final rows = await ServiceEvent().getEvents(
      tableName: TableNames.memoryTrace,
      inputUser: 'owner@example.com',
      storageLocation: DataStorageLocation.cloud,
      limit: 51,
      onPartialEvents: (events) {
        if (snapshots.isEmpty) expect(requests.length, 1);
        snapshots.add(events);
      },
    );
    expect(snapshots.map((events) => events.length), [6, 24]);
    expect(snapshots.first.last.masterGraphUrl, 'original-photo-5');
    expect(rows!.map((event) => event.id), List.generate(24, (i) => '$i'));
    expect(rows.last.masterGraphUrl, 'original-photo-23');
    expect(requests.length, 3);
  });

  test(
    'memory without progressive display keeps the original request count',
    () async {
      response = List.generate(24, (i) => {'id': '$i'});
      final rows = await ServiceEvent().getEvents(
        tableName: TableNames.memoryTrace,
        inputUser: 'owner@example.com',
        storageLocation: DataStorageLocation.cloud,
        limit: 51,
      );
      expect(rows!.length, 24);
      expect(requests.length, 2);
    },
  );

  test(
    'recommended places do not use the smaller memory-only first batch',
    () async {
      response = List.generate(24, (i) => {'id': '$i'});
      final snapshots = <int>[];
      final rows = await ServiceEvent().getEvents(
        tableName: TableNames.recommendPlaces,
        storageLocation: DataStorageLocation.local,
        limit: 51,
        onPartialEvents: (events) => snapshots.add(events.length),
      );
      expect(rows!.length, 24);
      expect(snapshots, [24]);
      expect(requests.length, 2);
    },
  );

  // No path-provider plugin or local DB is configured in this test. These
  // queries must therefore work without touching native local storage.
  test(
    'explicit cloud mode loads memory without opening the local DB',
    () async {
      final rows = await ServiceEvent().getEvents(
        tableName: TableNames.memoryTrace,
        inputUser: 'owner@example.com',
        storageLocation: DataStorageLocation.cloud,
      );
      expect(rows!.single.id, 'old');
      expect(requests.single.path, endsWith('/rpc/get_filtered_memory_trace'));
    },
  );

  test('cloud older-history checks also bypass the local DB', () async {
    final exists = await ServiceEvent().hasEventsBefore(
      tableName: TableNames.memoryTrace,
      before: DateTime(2026, 10),
      inputUser: 'owner@example.com',
      storageLocation: DataStorageLocation.cloud,
    );
    expect(exists, true);
    expect(requests.single.queryParameters['account'], 'eq.owner@example.com');
  });

  test('cloud fallback-date lookup also bypasses the local DB', () async {
    final latest = await ServiceEvent().latestEventDateBefore(
      tableName: TableNames.memoryTrace,
      before: DateTime(2026, 10),
      inputUser: 'owner@example.com',
      storageLocation: DataStorageLocation.cloud,
    );
    expect(latest, DateTime.utc(2026, 1, 1, 8).toLocal());
    expect(requests.single.queryParameters['account'], 'eq.owner@example.com');
  });

  test(
    'recommendations stay cloud-backed despite a local personal mode',
    () async {
      final rows = await ServiceEvent().getEvents(
        tableName: TableNames.recommendPlaces,
        inputUser: 'owner@example.com',
        storageLocation: DataStorageLocation.local,
      );
      expect(rows!.single.id, 'old');
      expect(
        requests.single.path,
        endsWith('/rpc/get_filtered_recommended_attractions'),
      );
    },
  );

  test(
    'fallback query provides a summary preview without an extra request',
    () async {
      EventItem? preview;
      final date = await ServiceEvent().latestEventDateBefore(
        tableName: TableNames.memoryTrace,
        before: DateTime(2026, 10),
        onLatestEvent: (event) => preview = event,
      );
      expect(preview?.id, 'old');
      expect(preview?.name, 'Old memory');
      expect(date, DateTime.utc(2026, 1, 1, 8).toLocal());
      expect(preview?.startDate, date);
      expect(requests.length, 1);
      final columns = requests.single.queryParameters['select']!.split(',');
      expect(
        columns,
        containsAll(['id', 'name', 'start_date', 'city', 'location']),
      );
      expect(columns, isNot(contains('master_graph_url')));
      expect(columns, isNot(contains('sub_events')));
      expect(requests.single.queryParameters['limit'], '1');
    },
  );

  test('date-only lookup retains the lightweight select', () async {
    response = [
      {'start_date': '2026-01-01T08:00:00Z'},
    ];
    await ServiceEvent().latestEventDateBefore(
      tableName: TableNames.memoryTrace,
      before: DateTime(2026, 10),
    );
    expect(requests.single.queryParameters['select'], 'start_date');
  });

  test('empty fallback does not publish a fake or empty record', () async {
    response = [];
    var callbacks = 0;
    final date = await ServiceEvent().latestEventDateBefore(
      tableName: TableNames.memoryTrace,
      before: DateTime(2026, 10),
      onLatestEvent: (_) => callbacks++,
    );
    expect(date, null);
    expect(callbacks, 0);
    expect(requests.length, 1);
  });
}
