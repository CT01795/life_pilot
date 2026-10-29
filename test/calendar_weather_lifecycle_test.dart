import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/auth/controller_auth.dart';
import 'package:life_pilot/calendar/controller_calendar.dart';
import 'package:life_pilot/calendar/controller_notification.dart';
import 'package:life_pilot/calendar/model_calendar.dart';
import 'package:life_pilot/event/model_event_item.dart';
import 'package:life_pilot/event/service_event.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/utils/app_navigator.dart' as navigation;
import 'package:life_pilot/utils/const.dart';
import 'package:life_pilot/utils/provider_locale.dart';
import 'package:life_pilot/utils/service/service_weather.dart';

class _Auth extends ControllerAuth {
  String account = 'one@example.com';
  @override
  String get currentAccount => account;
  @override
  bool get isSysAdmin => false;
}

class _Notifications implements ControllerNotification {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Weather extends ServiceWeather {
  void Function()? onRequest;
  final requests =
      <
        ({EventViewModel event, bool Function()? active, Completer<bool> done})
      >[];
  bool failSynchronously = false;
  @override
  Future<bool> preloadWeather(
    List<EventViewModel> events, {
    required String tableName,
    bool Function()? shouldContinue,
  }) {
    if (failSynchronously) throw StateError('weather unavailable');
    final done = Completer<bool>();
    requests.add((event: events.single, active: shouldContinue, done: done));
    onRequest?.call();
    return done.future;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ControllerCalendar c;
  late _Auth auth;
  late _Weather weather;
  late ProviderLocale locale;
  late Future<bool> Function() network;
  var networkReads = 0;
  List<EventItem> rows([int count = 1]) => [
    for (var i = 0; i < count; i++)
      EventItem(
        id: '$i',
        name: '$i',
        city: 'Taipei',
        location: 'Place $i',
        startDate: DateTime.now(),
      ),
  ];
  setUp(() {
    auth = _Auth();
    weather = _Weather();
    locale = ProviderLocale(locale: const Locale('en'));
    networkReads = 0;
    network = () async => true;
    c = ControllerCalendar(
      modelCalendar: ModelCalendar(),
      serviceEvent: ServiceEvent(),
      auth: auth,
      controllerNotification: _Notifications(),
      serviceWeather: weather,
      localeProvider: locale,
      tableName: TableNames.calendarEvents,
      toTableName: TableNames.memoryTrace,
      closeText: 'Close',
      networkAvailable: () {
        networkReads++;
        return network();
      },
    );
  });
  tearDown(() {
    if (!c.notifierDisposed) c.dispose();
    locale.dispose();
    auth.dispose();
  });
  Future<void> mount(WidgetTester tester) => tester.pumpWidget(
    MaterialApp(
      navigatorKey: navigation.navigatorKey,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      home: const SizedBox.shrink(),
    ),
  );
  void change(String action) {
    if (action == 'dispose') {
      c.dispose();
    } else if (action == 'account') {
      auth.account = 'other@example.com';
      c.updateAuth(auth);
    } else {
      c.clearAll(notify: false);
    }
  }

  test(
    'empty and disposed requests do not even check network availability',
    () async {
      await c.preloadWeatherForDay([]);
      c.dispose();
      await c.preloadWeatherForDay(rows());
      expect(networkReads, 0);
      expect(weather.requests, isEmpty);
    },
  );
  test('offline state performs no weather read', () async {
    network = () async => false;
    await c.preloadWeatherForDay(rows());
    expect(networkReads, 1);
    expect(weather.requests, isEmpty);
  });
  test(
    'network check failure is optional enrichment, not a page failure',
    () async {
      network = () => throw StateError('network check');
      await c.preloadWeatherForDay(rows());
      expect(weather.requests, isEmpty);
    },
  );
  for (final action in ['account', 'reset', 'dispose']) {
    testWidgets('$action during network wait prevents weather requests', (
      tester,
    ) async {
      await mount(tester);
      final gate = Completer<bool>();
      network = () => gate.future;
      final pending = c.preloadWeatherForDay(rows());
      change(action);
      gate.complete(true);
      await pending;
      expect(weather.requests, isEmpty);
      await tester.pumpWidget(const SizedBox.shrink());
    });
    testWidgets('$action during weather read prevents late publication', (
      tester,
    ) async {
      await mount(tester);
      final pending = c.preloadWeatherForDay(rows());
      await tester.pump();
      expect(weather.requests.length, 1);
      final request = weather.requests.single;
      expect(request.active!(), isTrue);
      change(action);
      expect(request.active!(), isFalse);
      var notifications = 0;
      if (!c.notifierDisposed) c.addListener(() => notifications++);
      request.done.complete(true);
      await pending;
      expect(notifications, 0);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
  for (final changed in [true, false]) {
    testWidgets('completed warmup notifies only if weather changed=$changed', (
      tester,
    ) async {
      await mount(tester);
      var notifications = 0;
      c.addListener(() => notifications++);
      final pending = c.preloadWeatherForDay(rows());
      await tester.pump();
      weather.requests.single.done.complete(changed);
      await pending;
      expect(notifications, changed ? 1 : 0);
      expect(weather.requests.single.active!(), isFalse);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
  testWidgets(
    'scope invalidated by the first service call skips remaining candidates',
    (tester) async {
      await mount(tester);
      weather.onRequest = () => c.clearAll(notify: false);
      final pending = c.preloadWeatherForDay(rows(3));
      await tester.pump();
      expect(weather.requests.length, 1);
      weather.requests.single.done.complete(true);
      await pending;
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'forecast window excludes ended and day-seven events but includes an ongoing event',
    (tester) async {
      await mount(tester);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      EventItem event(String id, DateTime? start, DateTime? end) => EventItem(
        id: id,
        name: id,
        city: 'Taipei',
        location: id,
        startDate: start,
        endDate: end,
      );
      final pending = c.preloadWeatherForDay([
        event(
          'ended',
          today.subtract(const Duration(days: 2)),
          today.subtract(const Duration(days: 1)),
        ),
        event('future', today.add(const Duration(days: 7)), null),
        event('undated', null, null),
        event('ongoing', today.subtract(const Duration(days: 2)), today),
      ]);
      await tester.pump();
      expect(weather.requests.map((r) => r.event.id), ['ongoing']);
      weather.requests.single.done.complete(false);
      await pending;
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets('warmup retains location deduplication and eight-location cap', (
    tester,
  ) async {
    await mount(tester);
    final source = rows(20);
    final pending = c.preloadWeatherForDay([
      source.first,
      source.first,
      ...source,
    ]);
    await tester.pump();
    expect(weather.requests.length, 8);
    expect(
      weather.requests.map((r) => r.event.locationDisplay).toSet().length,
      8,
    );
    for (final request in weather.requests) {
      request.done.complete(false);
    }
    await pending;
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('weather failures cannot become unhandled page errors', (
    tester,
  ) async {
    await mount(tester);
    final first = c.preloadWeatherForDay(rows(2));
    await tester.pump();
    weather.requests.first.done.completeError(StateError('weather'));
    await first;
    expect(weather.requests.every((r) => !r.active!()), isTrue);
    weather.requests.last.done.completeError(StateError('late weather'));
    await tester.pump();
    weather.failSynchronously = true;
    await c.preloadWeatherForDay(rows());
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
