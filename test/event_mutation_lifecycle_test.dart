import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/auth/controller_auth.dart';
import 'package:life_pilot/event/controller_event.dart';
import 'package:life_pilot/event/model_event.dart';
import 'package:life_pilot/event/model_event_item.dart';
import 'package:life_pilot/event/service_event.dart';
import 'package:life_pilot/event/service_event_public.dart';
import 'package:life_pilot/local_storage/local_data_store.dart';
import 'package:life_pilot/utils/const.dart';
import 'package:life_pilot/utils/service/service_weather.dart';

class _Auth extends ControllerAuth {
  String account = 'first@example.com';
  DataStorageLocation storage = DataStorageLocation.cloud;
  int usageReads = 0;
  Completer<void>? usageCompletion;
  @override
  String get currentAccount => account;
  @override
  DataStorageLocation get preferredStorage => storage;
  @override
  Future<void> refreshSubscriptionUsage({bool notify = true}) async {
    usageReads++;
    await usageCompletion?.future;
  }

  void change(bool local) {
    if (local) {
      storage = DataStorageLocation.local;
    } else {
      account = 'second@example.com';
    }
    notifyListeners();
  }
}

class _Service extends ServiceEvent {
  final completion = Completer<void>();
  int calls = 0;
  String? account;
  Future<void> record([String? owner]) {
    calls++;
    account = owner;
    return completion.future;
  }

  @override
  Future<void> saveEvent({
    required String currentAccount,
    required EventItem event,
    required bool isNew,
    required String tableName,
    String? originalAccount,
    bool? originalIsApproved,
  }) => record(currentAccount);
  @override
  Future<void> deleteEvent({
    required String currentAccount,
    required EventItem event,
    required String tableName,
  }) => record(currentAccount);
  @override
  Future<void> approvalEvent({
    required String eventId,
    required String tableName,
  }) => record();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final table in [
    TableNames.memoryTrace,
    TableNames.recommendEvents,
    TableNames.recommendPlaces,
  ]) {
    for (final operation in ['save', 'delete', 'approve']) {
      group('$table $operation', () {
        late _Auth auth;
        late _Service service;
        late ServiceEventPublic public;
        late ControllerEvent controller;
        late EventItem event;
        Future<void> act() => switch (operation) {
          'save' => controller.saveEvent(newEvent: event),
          'delete' => controller.deleteEvent(event),
          _ => controller.approveEvent(event: event),
        };
        setUp(() {
          auth = _Auth();
          service = _Service();
          public = ServiceEventPublic();
          event = EventItem(id: 'same-id', name: 'old', isApproved: false);
          controller = ControllerEvent(
            auth: auth,
            serviceEvent: service,
            serviceWeather: ServiceWeather(),
            serviceEventPublic: public,
            modelEvent: ModelEvent()..setEvents([event]),
            tableName: table,
          );
        });
        tearDown(() {
          if (!controller.notifierDisposed) controller.dispose();
          if (!service.completion.isCompleted) service.completion.complete();
          auth.dispose();
          public.close();
        });
        test('current scope applies successful operation', () async {
          final pending = act();
          service.completion.complete();
          await pending;
          expect(service.calls, 1);
          if (operation != 'approve') {
            expect(service.account, 'first@example.com');
          }
          expect(event.isApproved, operation == 'approve');
          expect(
            controller.modelEvent.removedEventIds.contains(event.id),
            operation == 'delete',
          );
        });
        for (final local in [false, true]) {
          test('scope change local=$local ignores late completion', () async {
            final pending = act();
            auth.change(local);
            final replacement = EventItem(id: event.id, name: 'new');
            controller.modelEvent.setEvents([replacement]);
            var notifications = 0;
            controller.addListener(() => notifications++);
            service.completion.complete();
            await pending;
            expect(auth.usageReads, 0);
            expect(notifications, 0);
            expect(event.isApproved, false);
            expect(controller.findEventById(event.id), same(replacement));
            expect(controller.modelEvent.removedEventIds, isEmpty);
          });
        }
        test('disposal ignores completion and blocks new work', () async {
          final pending = act();
          controller.dispose();
          service.completion.complete();
          await pending;
          await act();
          expect(service.calls, 1);
          expect(auth.usageReads, 0);
          expect(event.isApproved, false);
        });
        if (table == TableNames.memoryTrace && operation == 'delete') {
          test(
            'scope change during quota refresh preserves new model',
            () async {
              auth.usageCompletion = Completer<void>();
              final pending = act();
              service.completion.complete();
              await Future<void>.delayed(Duration.zero);
              expect(auth.usageReads, 1);
              auth.change(false);
              final replacement = EventItem(id: event.id, name: 'new');
              controller.modelEvent.setEvents([replacement]);
              auth.usageCompletion!.complete();
              await pending;
              expect(controller.findEventById(event.id), same(replacement));
              expect(controller.modelEvent.removedEventIds, isEmpty);
            },
          );
        }
      });
    }
  }
}
