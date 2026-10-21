import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/calendar/controller_calendar.dart';
import 'package:life_pilot/calendar/controller_notification.dart';
import 'package:life_pilot/calendar/model_calendar.dart';
import 'package:life_pilot/calendar/model_calendar_month_query.dart';
import 'package:life_pilot/calendar/service_calendar_month.dart';
import 'package:life_pilot/event/model_event_item.dart';
import 'package:life_pilot/event/service_event.dart';
import 'package:life_pilot/utils/const.dart';
import 'package:life_pilot/utils/provider_locale.dart';
import 'package:life_pilot/utils/service/service_weather.dart';

class _Model extends ModelCalendar {
  final requests = <Completer<List<EventItem>>>[];
  final months = <DateTime>[];
  final previews = <void Function(List<EventItem>)?>[];
}

class _Loader extends ServiceCalendarMonth {
  final _Model model;
  _Loader(this.model);
  @override
  Future<List<EventItem>> loadMonth(
    ModelCalendarMonthQuery query, {
    bool Function()? shouldContinue,
    void Function(List<EventItem>)? onEventsReady,
  }) {
    final pending = Completer<List<EventItem>>();
    model.months.add(query.month);
    model.previews.add(onEventsReady);
    model.requests.add(pending);
    return pending.future;
  }
}

class _Notifications implements ControllerNotification {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Model model;
  late ControllerCalendar controller;
  late ProviderLocale locale;
  List<EventItem> rows() => [
    EventItem(id: 'old', name: 'Old', startDate: DateTime(2026, 10, 1)),
  ];
  setUp(() {
    model = _Model();
    locale = ProviderLocale(locale: const Locale('en'));
    controller = ControllerCalendar(
      modelCalendar: model,
      monthLoader: _Loader(model),
      serviceEvent: ServiceEvent(),
      auth: null,
      controllerNotification: _Notifications(),
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
  });

  test(
    'disposed calendar does not populate caches from a late request',
    () async {
      final request = controller.reloadEvents();
      controller.dispose();
      model.requests.single.complete(rows());
      await request;
      expect(model.cachedEvents, isEmpty);
      expect(model.events, isEmpty);
    },
  );

  test(
    'preview is visible in the grid before the complete month returns',
    () async {
      final month = DateTime(2026, 10);
      controller.currentMonth = month;
      final pending = controller.reloadEvents(month: month);
      var updates = 0;
      controller.addListener(() => updates++);
      model.previews.single!(rows());
      expect(model.events.single.id, 'old');
      expect(model.eventsForMonth(month).single.id, 'old');
      expect(model.getEventsOfDay(DateTime(2026, 10, 1)).single.id, 'old');
      expect(updates, 1);
      model.requests.single.complete([
        ...rows(),
        EventItem(
          id: 'holiday',
          name: 'Holiday',
          startDate: DateTime(2026, 10, 2),
        ),
      ]);
      await pending;
      expect(model.eventsForMonth(month).length, 2);
    },
  );

  test(
    'failed provisional month is retried instead of treated as complete cache',
    () async {
      final month = DateTime(2026, 10);
      controller.currentMonth = month;
      final pending = controller.reloadEvents(month: month);
      model.previews.single!(rows());
      final failed = expectLater(pending, throwsStateError);
      model.requests.single.completeError(StateError('holidays failed'));
      await failed;
      final retry = controller.goToMonth(month: month);
      expect(model.requests.length, 2);
      controller.dispose();
      model.requests.last.complete([]);
      await retry;
    },
  );

  test('late previews cannot publish after scope reset', () async {
    final pending = controller.reloadEvents();
    controller.clearAll(notify: false);
    model.previews.single!(rows());
    expect(model.events, isEmpty);
    expect(model.cachedEvents, isEmpty);
    model.requests.single.complete(rows());
    await pending;
  });

  test('disposed calendar does not start another service read', () async {
    controller.dispose();
    await controller.reloadEvents();
    expect(model.requests, isEmpty);
  });

  test('leaving during month load does not start adjacent preload', () async {
    final pending = controller.goToMonth(month: DateTime(2026, 10));
    controller.dispose();
    model.requests.single.complete([]);
    await pending;
    expect(model.requests.length, 1);
  });

  test('reset during month load does not preload the old scope', () async {
    final pending = controller.goToMonth(month: DateTime(2026, 10));
    controller.clearAll(notify: false);
    model.requests.single.complete([]);
    await pending;
    expect(model.requests.length, 1);
  });

  test('old completion cannot unlock a newer month transition', () async {
    final old = controller.goToMonth(month: DateTime(2026, 10));
    controller.clearAll(notify: false);
    final fresh = controller.goToMonth(month: DateTime(2026, 11));
    expect(model.requests.length, 2);
    model.requests.first.complete([]);
    await old;
    await controller.goToMonth(month: DateTime(2026, 12));
    expect(model.requests.length, 2);
    controller.dispose();
    model.requests[1].complete([]);
    await fresh;
  });

  test('active month still refreshes both adjacent months', () async {
    final pending = controller.goToMonth(month: DateTime(2026, 10));
    model.requests.first.complete([]);
    await pending;
    expect(model.months, [
      DateTime(2026, 10),
      DateTime(2026, 11),
      DateTime(2026, 9),
    ]);
    for (final request in model.requests.skip(1)) {
      request.complete([]);
    }
    await Future<void>.delayed(Duration.zero);
  });

  test(
    'background failures do not escape or clear the visible month',
    () async {
      final pending = controller.goToMonth(month: DateTime(2026, 10));
      model.requests.first.complete(rows());
      await pending;
      for (final request in model.requests.skip(1)) {
        request.completeError(StateError('preload unavailable'));
      }
      await Future<void>.delayed(Duration.zero);
      expect(model.events.single.id, 'old');
      expect(model.cachedEvents.containsKey('2026-10'), true);
    },
  );

  test('foreground failure remains observable and allows retry', () async {
    final pending = controller.goToMonth(month: DateTime(2026, 10));
    final result = expectLater(pending, throwsStateError);
    model.requests.first.completeError(StateError('load failed'));
    await result;
    expect(model.requests.length, 1);
    final retry = controller.goToMonth(month: DateTime(2026, 10));
    expect(model.requests.length, 2);
    controller.dispose();
    model.requests.last.complete([]);
    await retry;
  });

  test('clearing scope rejects results from the previous generation', () async {
    final request = controller.reloadEvents();
    controller.clearAll(notify: false);
    model.requests.single.complete(rows());
    await request;
    expect(model.cachedEvents, isEmpty);
    expect(model.events, isEmpty);
  });

  test('superseded same-month response is ignored before cache work', () async {
    final first = controller.reloadEvents();
    final second = controller.reloadEvents();
    model.requests[0].complete(rows());
    await first;
    expect(model.cachedEvents, isEmpty);
    controller.dispose();
    model.requests[1].complete([]);
    await second;
  });
}
