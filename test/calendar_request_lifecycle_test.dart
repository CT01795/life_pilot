import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/auth/controller_auth.dart';
import 'package:life_pilot/calendar/controller_calendar.dart';
import 'package:life_pilot/calendar/controller_notification.dart';
import 'package:life_pilot/calendar/model_calendar.dart';
import 'package:life_pilot/event/model_event_item.dart';
import 'package:life_pilot/event/service_event.dart';
import 'package:life_pilot/utils/const.dart';
import 'package:life_pilot/utils/provider_locale.dart';
import 'package:life_pilot/utils/service/service_weather.dart';

class _Model extends ModelCalendar {
  final requests = <Completer<List<EventItem>>>[];
  @override
  Future<List<EventItem>> loadEventsFromService({
    required ServiceEvent serviceEvent,
    required DateTime month,
    required ControllerAuth? auth,
    required ProviderLocale localeProvider,
    required String tableName,
  }) {
    final pending = Completer<List<EventItem>>();
    requests.add(pending);
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
