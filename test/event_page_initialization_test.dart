import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/auth/controller_auth.dart';
import 'package:life_pilot/event/controller_event.dart';
import 'package:life_pilot/event/model_event.dart';
import 'package:life_pilot/event/model_event_item.dart';
import 'package:life_pilot/event/public_event_refresh.dart';
import 'package:life_pilot/event/service_event.dart';
import 'package:life_pilot/event/service_event_public.dart';
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
  bool get isSysAdmin => true;
  @override
  bool get storesNewDataLocally => local;
  @override
  DataStorageLocation get preferredStorage =>
      local ? DataStorageLocation.local : DataStorageLocation.cloud;
  void switchAccount() {
    account = 'two@example.com';
    notifyListeners();
  }
}

class _Events extends ServiceEvent {
  final calls = <({int? limit, int offset})>[];
  Completer<List<EventItem>>? pending;
  List<EventItem> rows = [];
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
    void Function(List<EventItem>)? onPartialEvents,
  }) async {
    calls.add((limit: limit, offset: offset));
    if (pending != null) return pending!.future;
    return rows.skip(offset).take(limit ?? rows.length).toList();
  }
}

class _Public extends ServiceEventPublic {
  int statusCalls = 0, refreshCalls = 0;
  Completer<PublicEventRefreshStatus>? status;
  Completer<PublicEventRefreshExecution>? execution;
  @override
  Future<PublicEventRefreshStatus> getRefreshStatus() async {
    statusCalls++;
    return status?.future ??
        const PublicEventRefreshStatus(updated: false, running: false);
  }

  @override
  Future<PublicEventRefreshExecution> fetchAndSaveAllEvents() async {
    refreshCalls++;
    return execution?.future ?? PublicEventRefreshExecution.performed;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Auth auth;
  late _Events events;
  late _Public public;
  late ControllerEvent controller;
  final loc = AppLocalizationsEn();
  setUp(() {
    auth = _Auth();
    events = _Events();
    public = _Public();
    controller = ControllerEvent(
      auth: auth,
      serviceEvent: events,
      serviceWeather: ServiceWeather(),
      modelEvent: ModelEvent(),
      serviceEventPublic: public,
      tableName: TableNames.recommendEvents,
    );
  });
  tearDown(() {
    if (!controller.notifierDisposed) controller.dispose();
    auth.dispose();
    public.close();
  });

  test(
    'concurrent page entries share the same load and status request',
    () async {
      events.pending = Completer<List<EventItem>>();
      final first = controller.initializePage();
      final second = controller.initializePage();
      expect(identical(first, second), true);
      expect(events.calls.length, 1);
      expect(public.statusCalls, 0);
      events.pending!.complete([]);
      await Future.wait([first, second]);
      expect(public.statusCalls, 1);
    },
  );

  test(
    'reentrant entry during loading notification shares pending operation',
    () async {
      Future<void>? nested;
      controller.addListener(() {
        if (controller.isLoadingEvents && nested == null) {
          nested = controller.initializePage();
        }
      });
      final first = controller.initializePage();
      expect(identical(first, nested), true);
      await first;
      expect(events.calls.length, 1);
      expect(public.statusCalls, 1);
    },
  );

  test(
    'account switch stops old entry before public status or auto refresh',
    () async {
      events.pending = Completer<List<EventItem>>();
      final first = controller.initializePage(autoRefreshPublicEvents: true);
      auth.switchAccount();
      events.pending!.complete([]);
      await first;
      expect(public.statusCalls, 0);
      expect(public.refreshCalls, 0);
      expect(controller.getFilteredEvents(loc), isEmpty);
    },
  );

  for (final local in [false, true]) {
    test(
      'refresh keeps bounded cloud pagination with storage local=$local',
      () async {
        auth.local = local;
        auth.notifyListeners();
        events.rows = List.generate(
          51,
          (i) => EventItem(id: '$i', name: '$i', startDate: DateTime.now()),
        );
        await controller.checkPublicEventsUpdatedToday();
        await controller.refreshPublicEvents();
        expect(events.calls.single.limit, 51);
        expect(controller.getFilteredEvents(loc).length, 50);
        expect(controller.hasMoreEvents, true);
        await controller.loadMoreRecommendedEvents();
        expect(events.calls.last.offset, 50);
        expect(controller.getFilteredEvents(loc).length, 51);
        expect(controller.hasMoreEvents, false);
      },
    );
  }

  test(
    'old refresh cannot load or publish data after account switch',
    () async {
      await controller.checkPublicEventsUpdatedToday();
      public.execution = Completer<PublicEventRefreshExecution>();
      final request = controller.refreshPublicEvents();
      auth.switchAccount();
      public.execution!.complete(PublicEventRefreshExecution.performed);
      expect(await request, false);
      expect(events.calls, isEmpty);
      expect(controller.isRefreshingPublicEvents, false);
    },
  );

  test(
    'late status response cannot enable refresh for another account',
    () async {
      public.status = Completer<PublicEventRefreshStatus>();
      final request = controller.checkPublicEventsUpdatedToday();
      auth.switchAccount();
      public.status!.complete(
        const PublicEventRefreshStatus(updated: false, running: false),
      );
      await request;
      expect(controller.canRefreshPublicEvents, false);
    },
  );

  test(
    'old refresh finishing cannot clear a newer refresh loading state',
    () async {
      await controller.checkPublicEventsUpdatedToday();
      final oldExecution = public.execution =
          Completer<PublicEventRefreshExecution>();
      final old = controller.refreshPublicEvents();
      auth.switchAccount();
      await controller.checkPublicEventsUpdatedToday();
      final newExecution = public.execution =
          Completer<PublicEventRefreshExecution>();
      final fresh = controller.refreshPublicEvents();
      oldExecution.complete(PublicEventRefreshExecution.performed);
      await old;
      expect(controller.isRefreshingPublicEvents, true);
      newExecution.complete(PublicEventRefreshExecution.performed);
      await fresh;
      expect(controller.isRefreshingPublicEvents, false);
      expect(events.calls.length, 1);
    },
  );

  test(
    'disposed page does not check public status after data returns',
    () async {
      events.pending = Completer<List<EventItem>>();
      final request = controller.initializePage(autoRefreshPublicEvents: true);
      controller.dispose();
      events.pending!.complete([]);
      await request;
      expect(public.statusCalls, 0);
      expect(public.refreshCalls, 0);
    },
  );
}
