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
import 'package:life_pilot/utils/model_event_weather.dart';
import 'package:life_pilot/utils/service/service_weather.dart';

class _Auth extends ControllerAuth {
  String account = 'one@example.com';
  bool local = false;
  @override
  String? get currentAccount => account;
  @override
  DataStorageLocation get preferredStorage =>
      local ? DataStorageLocation.local : DataStorageLocation.cloud;
  void change({bool storage = false}) {
    if (storage) {
      local = !local;
    } else {
      account = 'two@example.com';
    }
    notifyListeners();
  }
}

class _QueuedWeather extends ServiceWeather {
  final batches = <List<String>>[];
  final pending = <Completer<bool>>[];
  final guards = <bool Function()?>[];
  @override
  Future<bool> preloadWeather(
    List<EventViewModel> events, {
    required String tableName,
    bool Function()? shouldContinue,
  }) {
    batches.add(events.map((e) => e.id).toList());
    guards.add(shouldContinue);
    final completion = Completer<bool>();
    pending.add(completion);
    return completion.future;
  }
}

class _BatchWeather extends ServiceWeather {
  final first = Completer<List<EventWeather>?>();
  final calls = <String>[];
  @override
  Future<List<EventWeather>?> loadWeather({
    required EventViewModel event,
    required bool hasLocation,
    required String locationDisplay,
    required DateTime? startDate,
    required DateTime? endDate,
    required String tableName,
  }) {
    calls.add(event.id);
    return calls.length == 1 ? first.future : Future.value(null);
  }
}

EventViewModel view(String id) => EventViewModel(
  event: EventItem(id: id, name: id),
  id: id,
  name: id,
  showDate: false,
  startDate: null,
  endDate: null,
  dateRange: '',
  tags: [],
  hasLocation: true,
  locationDisplay: 'location-$id',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final table in [
    TableNames.recommendEvents,
    TableNames.recommendPlaces,
    TableNames.memoryTrace,
  ]) {
    group(table, () {
      late _Auth auth;
      late _QueuedWeather weather;
      late ServiceEventPublic public;
      late ControllerEvent controller;
      setUp(() {
        auth = _Auth();
        weather = _QueuedWeather();
        public = ServiceEventPublic();
      });
      // Construct inside the widget test's fake-clock zone so the initial
      // completed queue future and debounce timers share the same scheduler.
      void initialize() {
        controller = ControllerEvent(
          auth: auth,
          serviceEvent: ServiceEvent(),
          serviceWeather: weather,
          modelEvent: ModelEvent(),
          tableName: table,
          serviceEventPublic: public,
        );
      }

      tearDown(() {
        if (!controller.notifierDisposed) controller.dispose();
        for (final pending in weather.pending) {
          if (!pending.isCompleted) pending.complete(false);
        }
        auth.dispose();
        public.close();
      });

      testWidgets('account switch cancels pending debounce', (tester) async {
        initialize();
        controller.preloadWeatherForEvent(view('old'));
        auth.change();
        await tester.pump(const Duration(milliseconds: 100));
        expect(weather.batches, isEmpty);
      });

      for (final storage in [false, true]) {
        testWidgets(
          'scope switch storage=$storage drops queued work without blocking new requests',
          (tester) async {
            initialize();
            var notifications = 0;
            controller.addListener(() => notifications++);
            controller.preloadWeatherForEvent(view('first'));
            await tester.pump(const Duration(milliseconds: 100));
            controller.preloadWeatherForEvent(view('queued-old'));
            await tester.pump(const Duration(milliseconds: 100));
            expect(weather.batches, [
              ['first'],
            ]);
            auth.change(storage: storage);
            expect(weather.guards.first!(), isFalse);
            // The same event ID is eligible again in the new data scope.
            controller.preloadWeatherForEvent(view('first'));
            await tester.pump(const Duration(milliseconds: 100));
            expect(weather.batches, [
              ['first'],
              ['first'],
            ]);
            expect(weather.guards.last!(), isTrue);
            weather.pending.last.complete(true);
            await tester.pump();
            final afterCurrent = notifications;
            weather.pending.first.complete(true);
            await tester.pump();
            expect(notifications, afterCurrent);
            expect(weather.batches.length, 2);
          },
        );
      }

      testWidgets(
        'disposed controller neither queues work nor publishes late completion',
        (tester) async {
          initialize();
          var notifications = 0;
          controller.addListener(() => notifications++);
          controller.preloadWeatherForEvent(view('first'));
          await tester.pump(const Duration(milliseconds: 100));
          controller.preloadWeatherForEvent(view('queued'));
          await tester.pump(const Duration(milliseconds: 100));
          final before = notifications;
          controller.dispose();
          controller.preloadWeatherForEvent(view('after-dispose'));
          weather.pending.first.complete(true);
          await tester.pump(const Duration(milliseconds: 100));
          expect(weather.batches, [
            ['first'],
          ]);
          expect(weather.guards.single!(), isFalse);
          expect(notifications, before);
        },
      );

      testWidgets(
        'current scope batches stay serial and repeated IDs stay deduplicated',
        (tester) async {
          initialize();
          controller.preloadWeatherForEvent(view('first'));
          controller.preloadWeatherForEvent(view('first'));
          await tester.pump(const Duration(milliseconds: 100));
          controller.preloadWeatherForEvent(view('second'));
          await tester.pump(const Duration(milliseconds: 100));
          expect(weather.batches, [
            ['first'],
          ]);
          weather.pending.first.complete(true);
          await tester.pump();
          expect(weather.batches, [
            ['first'],
            ['second'],
          ]);
          weather.pending.last.complete(false);
          await tester.pump();
        },
      );

      testWidgets('a failed batch does not poison the next queued batch', (
        tester,
      ) async {
        initialize();
        controller.preloadWeatherForEvent(view('first'));
        await tester.pump(const Duration(milliseconds: 100));
        controller.preloadWeatherForEvent(view('second'));
        await tester.pump(const Duration(milliseconds: 100));
        weather.pending.first.completeError(StateError('weather unavailable'));
        await tester.pump();
        expect(weather.batches, [
          ['first'],
          ['second'],
        ]);
        weather.pending.last.complete(false);
        await tester.pump();
        expect(tester.takeException(), isNull);
      });
    });
  }

  test('service skips a batch whose owner is already stale', () async {
    final weather = _BatchWeather();
    expect(
      await weather.preloadWeather(
        [view('a')],
        tableName: TableNames.recommendPlaces,
        shouldContinue: () => false,
      ),
      isFalse,
    );
    expect(weather.calls, isEmpty);
  });

  test(
    'service stops later locations when scope changes during the first request',
    () async {
      final weather = _BatchWeather();
      var current = true;
      final pending = weather.preloadWeather(
        [view('a'), view('b')],
        tableName: TableNames.recommendPlaces,
        shouldContinue: () => current,
      );
      expect(weather.calls, ['a']);
      current = false;
      weather.first.complete(null);
      expect(await pending, isTrue);
      expect(weather.calls, ['a']);
    },
  );

  test(
    'service without a lifecycle guard still processes all locations',
    () async {
      final weather = _BatchWeather();
      final pending = weather.preloadWeather([
        view('a'),
        view('b'),
      ], tableName: TableNames.recommendPlaces);
      weather.first.complete(null);
      expect(await pending, isTrue);
      expect(weather.calls, ['a', 'b']);
    },
  );
}
