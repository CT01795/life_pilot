import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/auth/controller_auth.dart';
import 'package:life_pilot/calendar/controller_calendar.dart';
import 'package:life_pilot/calendar/controller_notification.dart';
import 'package:life_pilot/calendar/model_calendar.dart';
import 'package:life_pilot/calendar/model_calendar_month_query.dart';
import 'package:life_pilot/calendar/service_calendar_month.dart';
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
  final reminderReads = <String, Completer<List<String>>>{};
  final reminderCandidates = <String, Set<String>?>{};

  @override
  Future<List<String>> getCompletedCalendarEventIds({
    required String account,
    Set<String>? pendingEventIds,
  }) {
    reminderCandidates[account] = pendingEventIds;
    return reminderReads
        .putIfAbsent(account, Completer<List<String>>.new)
        .future;
  }

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
  Set<String>? reminderIds;
  @override
  Future<Set<String>?> pendingReminderEventIds() async => reminderIds;
  @override
  Future<void> cancelAllEventReminders({required String eventId}) async {
    cancelled.add(eventId);
    await pending?.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MonthLoader extends ServiceCalendarMonth {
  final pending = Completer<List<EventItem>>();

  @override
  Future<List<EventItem>> loadMonth(
    ModelCalendarMonthQuery query, {
    bool Function()? shouldContinue,
    void Function(List<EventItem>)? onEventsReady,
  }) => pending.future;
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
  late _MonthLoader loader;
  setUp(() {
    auth = _Auth();
    service = _Service();
    notifications = _Notifications();
    model = ModelCalendar();
    locale = ProviderLocale(locale: const Locale('en'));
    event = EventItem(
      id: 'event',
      name: 'old',
      startDate: DateTime(2026, 10, 9),
    );
    loader = _MonthLoader();
    model.setEvents([event]);
    controller = ControllerCalendar(
      modelCalendar: model,
      monthLoader: loader,
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

  test(
    'changed account starts a new reminder read and ignores old IDs',
    () async {
      notifications.reminderIds = {'old', 'new'};
      final old = controller.syncCompletedEventReminders();
      await Future<void>.delayed(Duration.zero);
      auth.account = 'two@example.com';
      controller.updateAuth(auth);
      final next = controller.syncCompletedEventReminders();
      await Future<void>.delayed(Duration.zero);
      expect(service.reminderCandidates['two@example.com'], {'old', 'new'});
      service.reminderReads['two@example.com']!.complete(['new']);
      await next;
      service.reminderReads['one@example.com']!.complete(['old']);
      await old;
      expect(notifications.cancelled, ['new']);
    },
  );

  test('no pending reminders skips the cloud read', () async {
    notifications.reminderIds = {};
    await controller.syncCompletedEventReminders();
    expect(service.reminderReads, isEmpty);
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

  test(
    'late month read cannot restore a deleted row or discard its peers',
    () async {
      final month = DateTime(2026, 10);
      final kept = EventItem(id: 'kept', name: 'kept', startDate: month);
      controller.currentMonth = month;
      model.setEvents([event, kept]);
      model.cacheMonthEvents(month, [event, kept]);
      final old = controller.reloadEvents();
      final deletion = controller.deleteEvent(event);
      service.deleted.complete();
      await deletion;
      loader.pending.complete([event, kept]);
      await old;
      expect(model.events, [kept]);
      expect(model.eventsForMonth(month), [kept]);
    },
  );

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
