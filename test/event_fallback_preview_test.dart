import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:life_pilot/event/model_event_item.dart';
import 'package:life_pilot/event/model_event_load_policy.dart';
import 'package:life_pilot/event/model_event_page.dart';
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
  late List<({int offset, int limit})> pages;
  setUp(() {
    requests = [];
    pages = [];
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
            pages.add((offset: offset, limit: limit));
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

  test(
    'memory publishes the configured photo preview before the rest',
    () async {
      final previewSize = ModelEventLoadPolicy.memory.previewBatchSize!;
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
      expect(snapshots.map((events) => events.length), [previewSize, 24]);
      expect(
        snapshots.first.last.masterGraphUrl,
        'original-photo-${previewSize - 1}',
      );
      expect(rows!.map((event) => event.id), List.generate(24, (i) => '$i'));
      expect(rows.last.masterGraphUrl, 'original-photo-23');
      expect(requests.length, 3);
    },
  );

  test(
    'memory policy pages retain photos and lookahead without gaps',
    () async {
      response = List.generate(
        24,
        (i) => {
          'id': '$i',
          'name': 'Memory $i',
          'master_graph_url': 'original-photo-$i',
          'start_date': '2026-10-01T08:00:00Z',
        },
      );
      final policy = ModelEventLoadPolicy.memory;
      final service = ServiceEvent();
      final snapshots = <int>[];
      final firstRows = await service.getEvents(
        tableName: TableNames.memoryTrace,
        inputUser: 'owner@example.com',
        storageLocation: DataStorageLocation.cloud,
        limit: policy.cloudPageSize + 1,
        onPartialEvents: (events) => snapshots.add(events.length),
      );
      final first = ModelEventPage.fromRows(
        firstRows!,
        pageSize: policy.cloudPageSize,
      );
      expect(snapshots, [policy.previewBatchSize, policy.cloudPageSize + 1]);
      expect(first.hasMore, true);
      final nextRows = await service.getEvents(
        tableName: TableNames.memoryTrace,
        inputUser: 'owner@example.com',
        storageLocation: DataStorageLocation.cloud,
        limit: policy.cloudPageSize + 1,
        offset: first.nextOffset,
      );
      final next = ModelEventPage.fromRows(
        nextRows!,
        pageSize: policy.cloudPageSize,
        offset: first.nextOffset,
      );
      final visible = [...first.events, ...next.events];
      expect(visible.map((event) => event.id), List.generate(24, (i) => '$i'));
      expect(
        visible.map((event) => event.masterGraphUrl),
        List.generate(24, (i) => 'original-photo-$i'),
      );
      expect(next.hasMore, false);
      expect(pages, [
        (offset: 0, limit: policy.previewBatchSize!),
        (
          offset: policy.previewBatchSize!,
          limit: policy.cloudPageSize + 1 - policy.previewBatchSize!,
        ),
        (offset: first.nextOffset, limit: policy.cloudPageSize + 1),
        (offset: 24, limit: 1),
      ]);
    },
  );

  test('scope ending after preview prevents another memory RPC', () async {
    response = List.generate(24, (i) => {'id': '$i'});
    var active = true;
    final snapshots = <int>[];
    final rows = await ServiceEvent().getEvents(
      tableName: TableNames.memoryTrace,
      inputUser: 'owner@example.com',
      storageLocation: DataStorageLocation.cloud,
      limit: ModelEventLoadPolicy.memory.cloudPageSize + 1,
      shouldContinue: () => active,
      onPartialEvents: (events) {
        snapshots.add(events.length);
        active = false;
      },
    );
    expect(snapshots, [ModelEventLoadPolicy.memory.previewBatchSize]);
    expect(requests.length, 1);
    expect(rows, isEmpty);
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
