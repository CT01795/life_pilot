import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/auth/controller_auth.dart';
import 'package:life_pilot/event/controller_event.dart';
import 'package:life_pilot/event/model_event.dart';
import 'package:life_pilot/event/model_event_item.dart';
import 'package:life_pilot/event/service_event.dart';
import 'package:life_pilot/l10n/app_localizations_en.dart';
import 'package:life_pilot/local_storage/local_data_store.dart';
import 'package:life_pilot/utils/const.dart';
import 'package:life_pilot/utils/service/service_weather.dart';

class _Auth extends ControllerAuth {
  String account = 'one@example.com';
  bool local = false;
  @override
  String? get currentAccount => account;
  @override
  bool get isSysAdmin => false;
  @override
  DataStorageLocation get preferredStorage =>
      local ? DataStorageLocation.local : DataStorageLocation.cloud;
  @override
  bool get storesNewDataLocally => local;
  void switchAccount() {
    account = 'two@example.com';
    notifyListeners();
  }
}

class _Service extends ServiceEvent {
  List<EventItem> rows = [
    EventItem(id: 'recent', name: 'Recent', startDate: DateTime.now()),
  ];
  final checks = <Completer<bool>>[];
  final boundaries = <DateTime>[];
  int reads = 0;
  bool paged = false;
  final windows =
      <({int? limit, int offset, DateTime? start, DateTime? end})>[];
  DateTime? latest;
  Completer<List<EventItem>>? pendingRows;
  Completer<List<EventItem>>? pendingFallback;
  void Function(List<EventItem>)? previewCallback;
  bool Function()? continueCallback;
  @override
  Future<List<EventItem>?> getEvents({
    required String tableName,
    DateTime? dateS,
    DateTime? dateE,
    String? id,
    String? inputUser,
    DataStorageLocation? storageLocation,
    int? limit,
    int offset = 0,
    void Function(List<EventItem> events)? onPartialEvents,
    bool Function()? shouldContinue,
  }) async {
    reads++;
    continueCallback = shouldContinue;
    windows.add((limit: limit, offset: offset, start: dateS, end: dateE));
    previewCallback = onPartialEvents;
    if (reads > 1 && pendingFallback != null) return pendingFallback!.future;
    if (pendingRows != null) return pendingRows!.future;
    if (latest != null && reads == 1) return [];
    if (paged) return rows.skip(offset).take(limit ?? rows.length).toList();
    return rows;
  }

  @override
  Future<DateTime?> latestEventDateBefore({
    required String tableName,
    required DateTime before,
    String? inputUser,
    DataStorageLocation? storageLocation,
    void Function(EventItem event)? onLatestEvent,
  }) async {
    if (latest != null && rows.isNotEmpty) onLatestEvent?.call(rows.first);
    return latest;
  }

  @override
  Future<bool> hasEventsBefore({
    required String tableName,
    required DateTime before,
    String? inputUser,
    DataStorageLocation? storageLocation,
  }) {
    boundaries.add(before);
    final check = Completer<bool>();
    checks.add(check);
    return check.future;
  }
}

Future<void> _flush() => Future<void>.delayed(Duration.zero);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Auth auth;
  late _Service service;
  late ControllerEvent controller;
  final loc = AppLocalizationsEn();
  setUp(() {
    auth = _Auth();
    service = _Service();
    controller = ControllerEvent(
      auth: auth,
      serviceEvent: service,
      serviceWeather: ServiceWeather(),
      modelEvent: ModelEvent(),
      tableName: TableNames.memoryTrace,
    );
  });
  tearDown(() {
    if (!controller.notifierDisposed) controller.dispose();
    auth.dispose();
  });

  for (final local in [false, true]) {
    test(
      'older fallback is visible before full day query finishes local=$local',
      () async {
        auth.local = local;
        auth.notifyListeners();
        final date = DateTime.now().subtract(const Duration(days: 100));
        service.latest = date;
        service.rows = [EventItem(id: 'old', name: 'Old', startDate: date)];
        service.pendingFallback = Completer<List<EventItem>>();
        final request = controller.loadEvents(isGetPublicEvents: false);
        await _flush();
        expect(service.reads, 2);
        expect(controller.getFilteredEvents(loc).single.id, 'old');
        expect(controller.isLoadingMemoryRecords, true);
        service.pendingFallback!.complete(service.rows);
        await _flush();
        service.checks.single.complete(false);
        await request;
        expect(controller.isLoadingMemoryRecords, false);
      },
    );
  }

  for (final local in [false, true]) {
    test(
      'first rows are visible while ${local ? 'local' : 'cloud'} load waits',
      () async {
        auth.local = local;
        auth.notifyListeners();
        final completion = service.pendingRows = Completer<List<EventItem>>();
        final request = controller.loadEvents(isGetPublicEvents: false);
        service.previewCallback!(service.rows);
        expect(controller.hasLoadedEventsSuccessfully, true);
        expect(controller.isLoadingEvents, true);
        expect(controller.isLoadingMemoryRecords, true);
        expect(controller.isLoadingMoreMemory, true);
        expect(controller.getFilteredEvents(loc).single.id, 'recent');
        completion.complete(service.rows);
        await _flush();
        expect(controller.isLoadingMemoryRecords, false);
        service.checks.single.complete(false);
        await request;
        expect(controller.isLoadingEvents, false);
      },
    );
  }

  test('late preview cannot restore records after account switch', () async {
    final completion = service.pendingRows = Completer<List<EventItem>>();
    final request = controller.loadEvents(isGetPublicEvents: false);
    final oldCallback = service.previewCallback!;
    auth.switchAccount();
    oldCallback(service.rows);
    completion.complete(service.rows);
    await request;
    expect(controller.getFilteredEvents(loc), isEmpty);
    expect(controller.hasLoadedEventsSuccessfully, false);
  });

  test(
    'progressive and final publishing reuse unchanged card models',
    () async {
      final completion = service.pendingRows = Completer<List<EventItem>>();
      final request = controller.loadEvents(isGetPublicEvents: false);
      service.previewCallback!(service.rows);
      final first = controller.buildViewModel(
        event: service.rows.first,
        loc: loc,
      );
      service.previewCallback!([
        ...service.rows,
        EventItem(id: 'another', name: 'Another', startDate: DateTime.now()),
      ]);
      expect(
        controller.buildViewModel(event: service.rows.first, loc: loc),
        same(first),
      );
      completion.complete(service.rows);
      await _flush();
      expect(
        controller.buildViewModel(event: service.rows.first, loc: loc),
        same(first),
      );
      service.checks.single.complete(false);
      await request;
      expect(
        controller.buildViewModel(event: service.rows.first, loc: loc),
        same(first),
      );
    },
  );

  test('late preview after disposal is ignored', () async {
    final completion = service.pendingRows = Completer<List<EventItem>>();
    final request = controller.loadEvents(isGetPublicEvents: false);
    expect(service.continueCallback!(), true);
    controller.dispose();
    expect(service.continueCallback!(), false);
    service.previewCallback!(service.rows);
    completion.complete(service.rows);
    await request;
    expect(controller.hasLoadedEventsSuccessfully, false);
  });

  for (final local in [false, true]) {
    test(
      'scope predicate expires after account/storage change local=$local',
      () async {
        final completion = service.pendingRows = Completer<List<EventItem>>();
        final request = controller.loadEvents(isGetPublicEvents: false);
        final active = service.continueCallback!;
        expect(active(), true);
        if (local) {
          auth.local = true;
          auth.notifyListeners();
        } else {
          auth.switchAccount();
        }
        expect(active(), false);
        completion.complete(service.rows);
        await request;
        expect(controller.getFilteredEvents(loc), isEmpty);
      },
    );
  }

  test('expired service query does not access storage or network', () async {
    for (final storage in DataStorageLocation.values) {
      final rows = await ServiceEvent().getEvents(
        tableName: TableNames.memoryTrace,
        inputUser: 'expired@example.com',
        storageLocation: storage,
        shouldContinue: () => false,
      );
      expect(rows, isEmpty);
    }
  });

  test(
    'later query failure retains preview and load-more retries initial load',
    () async {
      final completion = service.pendingRows = Completer<List<EventItem>>();
      final request = controller.loadEvents(isGetPublicEvents: false);
      service.previewCallback!(service.rows);
      completion.completeError(StateError('next page failed'));
      await request;
      expect(controller.hasLoadEventsError, true);
      expect(controller.getFilteredEvents(loc).single.id, 'recent');
      expect(controller.isLoadingMoreMemory, false);
      service.pendingRows = null;
      final retry = controller.loadMoreMemoryEvents();
      await _flush();
      service.checks.single.complete(false);
      await retry;
      expect(service.reads, 2);
      expect(controller.hasLoadEventsError, false);
      expect(controller.getFilteredEvents(loc).single.id, 'recent');
    },
  );

  testWidgets(
    'load-more metadata timeout preserves rows and releases loading',
    (tester) async {
      final initial = controller.loadEvents(isGetPublicEvents: false);
      await tester.pump();
      service.checks.single.complete(true);
      await initial;
      final oldDate = DateTime.now().subtract(const Duration(days: 100));
      service.latest = oldDate;
      service.rows = [
        EventItem(id: 'older', name: 'Older', startDate: oldDate),
      ];
      final pending = controller.loadMoreMemoryEvents();
      await tester.pump();
      expect(service.checks.length, 2);
      expect(
        controller.getFilteredEvents(loc).map((e) => e.id),
        contains('older'),
      );
      expect(controller.isLoadingMoreMemory, true);
      await tester.pump(const Duration(seconds: 10));
      await pending;
      expect(controller.isLoadingMoreMemory, false);
      expect(controller.hasMoreMemory, true);
      expect(controller.hasLoadEventsError, false);
      service.checks.last.complete(false);
      await tester.pump();
      expect(controller.hasMoreMemory, true);
    },
  );

  for (final change in ['account', 'storage', 'dispose']) {
    test('late load-more metadata cannot update after $change', () async {
      final initial = controller.loadEvents(isGetPublicEvents: false);
      await _flush();
      service.checks.single.complete(true);
      await initial;
      final oldDate = DateTime.now().subtract(const Duration(days: 100));
      service.latest = oldDate;
      service.rows = [
        EventItem(id: 'older', name: 'Older', startDate: oldDate),
      ];
      final pending = controller.loadMoreMemoryEvents();
      await _flush();
      expect(service.checks.length, 2);
      var updates = 0;
      controller.addListener(() => updates++);
      if (change == 'account') {
        auth.switchAccount();
      } else if (change == 'storage') {
        auth.local = true;
        auth.notifyListeners();
      } else {
        controller.dispose();
      }
      final before = controller.hasMoreMemory;
      updates = 0;
      service.checks.last.complete(!before);
      await pending;
      expect(controller.hasMoreMemory, before);
      expect(updates, 0);
    });
  }

  test(
    'load-more metadata failure keeps new rows and permits another attempt',
    () async {
      final initial = controller.loadEvents(isGetPublicEvents: false);
      await _flush();
      service.checks.single.complete(true);
      await initial;
      final oldDate = DateTime.now().subtract(const Duration(days: 100));
      service.latest = oldDate;
      service.rows = [
        EventItem(id: 'older', name: 'Older', startDate: oldDate),
      ];
      final pending = controller.loadMoreMemoryEvents();
      await _flush();
      service.checks.last.completeError(
        StateError('history metadata unavailable'),
      );
      await pending;
      expect(controller.getFilteredEvents(loc).map((e) => e.id).toSet(), {
        'recent',
        'older',
      });
      expect(controller.hasMoreMemory, true);
      expect(controller.isLoadingMoreMemory, false);
      service.latest = null;
      await controller.loadMoreMemoryEvents();
      expect(controller.hasMoreMemory, false);
      expect(controller.getFilteredEvents(loc).length, 2);
    },
  );

  testWidgets('history metadata timeout does not leave loading stuck', (
    tester,
  ) async {
    final pending = controller.loadEvents(isGetPublicEvents: false);
    await tester.pump();
    expect(controller.hasLoadedEventsSuccessfully, true);
    expect(controller.isLoadingMoreMemory, true);
    await tester.pump(const Duration(seconds: 10));
    await pending;
    expect(controller.isLoadingEvents, false);
    expect(controller.isLoadingMoreMemory, false);
    expect(controller.hasLoadEventsError, false);
    expect(controller.hasMoreMemory, true);
    service.checks.single.complete(false);
    await tester.pump();
  });

  test('records are published before history metadata completes', () async {
    var published = false;
    controller.addListener(() {
      if (controller.hasLoadedEventsSuccessfully &&
          controller.getFilteredEvents(loc).isNotEmpty) {
        published = true;
      }
    });
    final pending = controller.loadEvents(isGetPublicEvents: false);
    await _flush();
    expect(service.checks.length, 1);
    expect(published, true);
    expect(controller.hasLoadedEventsSuccessfully, true);
    expect(controller.getFilteredEvents(loc).single.id, 'recent');
    expect(controller.isLoadingMoreMemory, true);
    service.checks.single.complete(false);
    await pending;
    expect(controller.isLoadingEvents, false);
    expect(controller.isLoadingMoreMemory, false);
    expect(controller.hasMoreMemory, false);
  });
  test(
    'metadata failure keeps records and a retryable history button',
    () async {
      final pending = controller.loadEvents(isGetPublicEvents: false);
      await _flush();
      service.checks.single.completeError(StateError('metadata unavailable'));
      await pending;
      expect(controller.getFilteredEvents(loc).single.id, 'recent');
      expect(controller.hasLoadEventsError, false);
      expect(controller.hasMoreMemory, true);
      expect(controller.isLoadingMoreMemory, false);
    },
  );
  test('load-more cannot race the first metadata request', () async {
    final pending = controller.loadEvents(isGetPublicEvents: false);
    await _flush();
    await controller.loadMoreMemoryEvents();
    await controller.loadEvents(isGetPublicEvents: false);
    expect(service.reads, 1);
    expect(service.checks.length, 1);
    service.checks.single.complete(false);
    await pending;
  });
  test(
    'full cloud page skips unnecessary history availability query',
    () async {
      service.rows = List.generate(
        51,
        (i) => EventItem(id: '$i', name: '$i', startDate: DateTime.now()),
      );
      await controller.loadEvents(isGetPublicEvents: false);
      expect(service.checks, isEmpty);
      expect(controller.getFilteredEvents(loc).length, 12);
      expect(controller.hasMoreMemory, true);
    },
  );
  test(
    'small cloud pages retain lookahead and future-date query bounds',
    () async {
      service.paged = true;
      final future = DateTime.now().add(const Duration(days: 7));
      service.rows = List.generate(
        25,
        (i) => EventItem(id: '$i', name: '$i', startDate: future),
      );
      await controller.loadEvents(isGetPublicEvents: false);
      expect(controller.getFilteredEvents(loc).length, 12);
      expect(service.windows.single.limit, 13);
      final firstWindow = service.windows.single;
      expect(firstWindow.end!.isAfter(future), true);
      await controller.loadMoreMemoryEvents();
      expect(controller.getFilteredEvents(loc).length, 24);
      expect(service.windows.last.offset, 12);
      expect(service.windows.last.start, firstWindow.start);
      expect(service.windows.last.end, firstWindow.end);
      expect(controller.hasMoreMemory, true);
      await controller.loadMoreMemoryEvents();
      expect(service.windows.map((window) => window.offset), [0, 12, 24]);
      expect(
        controller.getFilteredEvents(loc).map((event) => event.id).toSet(),
        service.rows.map((event) => event.id).toSet(),
      );
      expect(controller.getFilteredEvents(loc).length, 25);
      expect(controller.hasMoreMemory, false);
    },
  );
  test('local history is not truncated to the cloud page size', () async {
    auth.local = true;
    auth.notifyListeners();
    service.paged = true;
    service.rows = List.generate(
      25,
      (i) => EventItem(id: '$i', name: '$i', startDate: DateTime.now()),
    );
    final pending = controller.loadEvents(isGetPublicEvents: false);
    await _flush();
    service.checks.single.complete(false);
    await pending;
    expect(service.windows.single.limit, isNull);
    expect(controller.getFilteredEvents(loc).length, 25);
  });
  test(
    'account switch discards old metadata and does not block new load',
    () async {
      final old = controller.loadEvents(isGetPublicEvents: false);
      await _flush();
      auth.switchAccount();
      expect(controller.getFilteredEvents(loc), isEmpty);
      expect(controller.isLoadingMoreMemory, false);
      service.rows = [
        EventItem(id: 'new', name: 'New', startDate: DateTime.now()),
      ];
      final fresh = controller.loadEvents(isGetPublicEvents: false);
      await _flush();
      service.checks[0].complete(true);
      await old;
      expect(controller.isLoadingMoreMemory, true);
      service.checks[1].complete(false);
      await fresh;
      expect(controller.getFilteredEvents(loc).single.id, 'new');
      expect(controller.hasMoreMemory, false);
    },
  );
  test('disposal ignores late history results', () async {
    final pending = controller.loadEvents(isGetPublicEvents: false);
    await _flush();
    var notifications = 0;
    controller.addListener(() => notifications++);
    controller.dispose();
    service.checks.single.complete(false);
    await pending;
    expect(notifications, 0);
  });
  test(
    'latest older fallback is still visible before metadata finishes',
    () async {
      final oldDate = DateTime.now().subtract(const Duration(days: 100));
      service.latest = oldDate;
      service.rows = [EventItem(id: 'old', name: 'Old', startDate: oldDate)];
      final pending = controller.loadEvents(isGetPublicEvents: false);
      await _flush();
      expect(service.reads, 2);
      expect(controller.getFilteredEvents(loc).single.id, 'old');
      expect(
        service.boundaries.single,
        DateTime(oldDate.year, oldDate.month, oldDate.day),
      );
      service.checks.single.complete(false);
      await pending;
    },
  );
}
