import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/auth/controller_auth.dart';
import 'package:life_pilot/event/controller_event.dart';
import 'package:life_pilot/event/model_event.dart';
import 'package:life_pilot/event/model_event_item.dart';
import 'package:life_pilot/event/model_memory_initial_window.dart';
import 'package:life_pilot/event/service_event.dart';
import 'package:life_pilot/l10n/app_localizations_en.dart';
import 'package:life_pilot/local_storage/local_data_store.dart';
import 'package:life_pilot/utils/const.dart';
import 'package:life_pilot/utils/service/service_weather.dart';

class _Auth extends ControllerAuth {
  String owner = 'one@example.com';
  bool local = true;
  @override
  String get currentAccount => owner;
  @override
  bool get isSysAdmin => false;
  @override
  DataStorageLocation get preferredStorage =>
      local ? DataStorageLocation.local : DataStorageLocation.cloud;
  @override
  bool get storesNewDataLocally => local;
}

class _Service extends ServiceEvent {
  final localReads =
      <
        ({
          String owner,
          DateTime from,
          DateTime to,
          bool older,
          Completer<ModelMemoryInitialWindow> result,
        })
      >[];
  final cloudReads = <({DateTime from, DateTime to, int offset})>[];
  List<EventItem> cloudRows = [];

  @override
  Future<ModelMemoryInitialWindow> getLocalMemoryWindow({
    required String owner,
    required DateTime from,
    required DateTime to,
    bool older = false,
  }) {
    final result = Completer<ModelMemoryInitialWindow>();
    localReads.add((
      owner: owner,
      from: from,
      to: to,
      older: older,
      result: result,
    ));
    return result.future;
  }

  @override
  Future<ModelMemoryInitialWindow> getMemoryWindow({
    required DateTime from,
    required DateTime to,
    required int limit,
    int offset = 0,
    bool expandFallback = false,
  }) async {
    cloudReads.add((from: from, to: to, offset: offset));
    final rows = cloudRows.skip(offset).take(limit).toList();
    final more = offset + rows.length < cloudRows.length;
    return ModelMemoryInitialWindow(
      events: rows,
      hasPageMore: more,
      hasMore: more,
      windowStart: from,
      windowEnd: to,
    );
  }
}

ModelMemoryInitialWindow _page(
  DateTime day,
  List<String> ids, {
  bool more = false,
}) => ModelMemoryInitialWindow(
  events: [for (final id in ids) EventItem(id: id, name: id, startDate: day)],
  hasPageMore: false,
  hasMore: more,
  windowStart: day,
  windowEnd: day,
  nextDate: more ? day.subtract(const Duration(days: 100)) : null,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Auth auth;
  late _Service service;
  late ControllerEvent controller;
  final loc = AppLocalizationsEn();
  final now = DateTime(2026, 11, 27);
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

  test(
    'one local request publishes rows and continuation; rejects overlapping load more',
    () async {
      final first = controller.loadEvents(isGetPublicEvents: false);
      expect(service.localReads, hasLength(1));
      await controller.loadMoreMemoryEvents();
      expect(service.localReads, hasLength(1));
      service.localReads.single.result.complete(
        _page(now, List.generate(25, (i) => '$i'), more: true),
      );
      await first;
      expect(controller.getFilteredEvents(loc), hasLength(25));
      expect(controller.hasMoreMemory, true);
      final old = controller.loadMoreMemoryEvents();
      expect(service.localReads.last.from, now);
      expect(service.localReads.last.older, true);
      service.localReads.last.result.complete(_page(DateTime(2025), ['old']));
      await old;
      expect(controller.getFilteredEvents(loc), hasLength(26));
      expect(controller.hasMoreMemory, false);
      expect(service.localReads, hasLength(2));
    },
  );

  test(
    'account change ignores the late local result and does not block new load',
    () async {
      final old = controller.loadEvents(isGetPublicEvents: false);
      auth.owner = 'two@example.com';
      auth.notifyListeners();
      final fresh = controller.loadEvents(isGetPublicEvents: false);
      expect(service.localReads.last.owner, 'two@example.com');
      service.localReads.last.result.complete(_page(now, ['new']));
      await fresh;
      service.localReads.first.result.complete(_page(now, ['old'], more: true));
      await old;
      expect(controller.getFilteredEvents(loc).single.id, 'new');
      expect(controller.hasMoreMemory, false);
    },
  );

  test(
    'failed old window can be retried without losing the first window',
    () async {
      final first = controller.loadEvents(isGetPublicEvents: false);
      service.localReads.single.result.complete(
        _page(now, ['new'], more: true),
      );
      await first;
      final request = controller.loadMoreMemoryEvents();
      final failure = expectLater(request, throwsStateError);
      service.localReads.last.result.completeError(StateError('failed'));
      await failure;
      expect(controller.getFilteredEvents(loc).single.id, 'new');
      expect(controller.hasMoreMemory, true);
      final retry = controller.loadMoreMemoryEvents();
      service.localReads.last.result.complete(_page(DateTime(2025), ['old']));
      await retry;
      expect(controller.getFilteredEvents(loc), hasLength(2));
    },
  );

  test('cloud page preserves lookahead and future-date bounds', () async {
    auth.local = false;
    auth.notifyListeners();
    final future = DateTime.now().add(const Duration(days: 7));
    service.cloudRows = List.generate(
      25,
      (i) => EventItem(id: '$i', name: '$i', startDate: future),
    );
    await controller.loadEvents(isGetPublicEvents: false);
    expect(controller.getFilteredEvents(loc), hasLength(12));
    expect(service.cloudReads.single.to.isAfter(future), true);
    await controller.loadMoreMemoryEvents();
    await controller.loadMoreMemoryEvents();
    expect(service.cloudReads.map((page) => page.offset), [0, 12, 24]);
    expect(
      service.cloudReads.map((page) => (page.from, page.to)).toSet(),
      hasLength(1),
    );
    expect(controller.getFilteredEvents(loc), hasLength(25));
    expect(controller.hasMoreMemory, false);
    expect(service.localReads, isEmpty);
  });
}
