import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/auth/controller_auth.dart';
import 'package:life_pilot/calendar/controller_calendar.dart';
import 'package:life_pilot/calendar/controller_notification.dart';
import 'package:life_pilot/calendar/model_calendar.dart';
import 'package:life_pilot/event/model_event_item.dart';
import 'package:life_pilot/event/service_event.dart';
import 'package:life_pilot/local_storage/local_data_store.dart';
import 'package:life_pilot/utils/const.dart';
import 'package:life_pilot/utils/provider_locale.dart';
import 'package:life_pilot/utils/service/service_weather.dart';

class _Auth extends ControllerAuth {
  String account = 'one@example.com';
  DataStorageLocation storage = DataStorageLocation.cloud;
  @override
  String get currentAccount => account;
  @override
  DataStorageLocation get preferredStorage => storage;
}

class _Service extends ServiceEvent {
  final deleted = Completer<void>();
  int calls = 0;
  String? owner;
  @override
  Future<void> deleteEvent({
    required String currentAccount,
    required EventItem event,
    required String tableName,
  }) {
    calls++;
    owner = currentAccount;
    return deleted.future;
  }
}

class _Notifications implements ControllerNotification {
  final cancelled = <String>[];
  Completer<void>? pending;
  @override
  Future<void> cancelAllEventReminders({required String eventId}) async {
    cancelled.add(eventId);
    await pending?.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Auth auth;
  late _Service service;
  late _Notifications notifications;
  late ModelCalendar model;
  late ControllerCalendar controller;
  late ProviderLocale locale;
  late EventItem event;
  setUp(() {
    auth = _Auth();
    service = _Service();
    notifications = _Notifications();
    model = ModelCalendar();
    locale = ProviderLocale(locale: const Locale('en'));
    event = EventItem(id: 'event', name: 'old');
    model.setEvents([event]);
    controller = ControllerCalendar(
      modelCalendar: model,
      serviceEvent: service,
      auth: auth,
      controllerNotification: notifications,
      serviceWeather: ServiceWeather(),
      localeProvider: locale,
      tableName: TableNames.calendarEvents,
      toTableName: TableNames.memoryTrace,
      closeText: 'Close',
    );
  });
  tearDown(() {
    if (!controller.notifierDisposed) controller.dispose();
    locale.dispose();
    auth.dispose();
  });

  test('only confirmed deletion cancels reminder and updates model', () async {
    final pending = controller.deleteEvent(event);
    expect(service.owner, 'one@example.com');
    expect(notifications.cancelled, isEmpty);
    expect(model.events, [event]);
    service.deleted.complete();
    await pending;
    expect(notifications.cancelled, ['event']);
    expect(model.events, isEmpty);
    expect(model.removedEventIds, contains('event'));
  });

  test('failed deletion preserves reminders and visible data', () async {
    final pending = controller.deleteEvent(event);
    final result = expectLater(pending, throwsStateError);
    service.deleted.completeError(StateError('denied'));
    await result;
    expect(notifications.cancelled, isEmpty);
    expect(model.events, [event]);
    expect(model.removedEventIds, isEmpty);
  });

  for (final local in [false, true]) {
    test(
      'scope switch local=$local preserves new model but cancels deleted reminder',
      () async {
        final pending = controller.deleteEvent(event);
        if (local) {
          auth.storage = DataStorageLocation.local;
        } else {
          auth.account = 'two@example.com';
        }
        controller.updateAuth(auth);
        final replacement = EventItem(id: event.id, name: 'new');
        model.setEvents([replacement]);
        var updates = 0;
        controller.addListener(() => updates++);
        service.deleted.complete();
        await pending;
        expect(notifications.cancelled, ['event']);
        expect(model.events, [replacement]);
        expect(model.removedEventIds, isEmpty);
        expect(updates, 0);
      },
    );
  }

  test(
    'scope change while cancelling reminder cannot remove new data',
    () async {
      notifications.pending = Completer<void>();
      final pending = controller.deleteEvent(event);
      service.deleted.complete();
      await Future<void>.delayed(Duration.zero);
      expect(notifications.cancelled, ['event']);
      auth.account = 'two@example.com';
      controller.updateAuth(auth);
      final replacement = EventItem(id: event.id, name: 'new');
      model.setEvents([replacement]);
      notifications.pending!.complete();
      await pending;
      expect(model.events, [replacement]);
      expect(model.removedEventIds, isEmpty);
    },
  );

  test(
    'disposal preserves cancellation of successfully deleted event',
    () async {
      final pending = controller.deleteEvent(event);
      controller.dispose();
      service.deleted.complete();
      await pending;
      expect(notifications.cancelled, ['event']);
      expect(model.events, [event]);
      await controller.deleteEvent(event);
      expect(service.calls, 1);
    },
  );
}
