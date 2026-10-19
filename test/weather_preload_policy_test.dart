import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/event/model_event_item.dart';
import 'package:life_pilot/utils/const.dart';
import 'package:life_pilot/utils/model_event_weather.dart';
import 'package:life_pilot/utils/service/service_weather.dart';
import 'package:life_pilot/utils/weather_cache_store.dart';

class _Weather extends ServiceWeather {
  final calls = <String>[];
  @override
  Future<List<EventWeather>?> loadWeather({
    required EventViewModel event,
    required bool hasLocation,
    required String locationDisplay,
    required DateTime? startDate,
    required DateTime? endDate,
    required String tableName,
  }) async {
    calls.add(locationDisplay);
    // No result simulates geocoding/weather failure without using the network.
    return null;
  }
}

EventViewModel view(
  String id, {
  DateTime? start,
  DateTime? end,
  String location = 'Taipei',
  bool hasLocation = true,
}) => EventViewModel(
  event: EventItem(id: id, name: id),
  id: id,
  name: id,
  showDate: true,
  startDate: start,
  endDate: end,
  dateRange: '',
  tags: [],
  hasLocation: hasLocation,
  locationDisplay: location,
);

void main() {
  late _Weather weather;
  late DateTime today;
  final store = WeatherCacheStore.I;
  setUp(() {
    store.cache.clear();
    store.loading.clear();
    weather = _Weather();
    final now = DateTime.now();
    today = DateTime(now.year, now.month, now.day);
  });
  tearDown(() {
    store.cache.clear();
    store.loading.clear();
  });

  test(
    'same-location cards attempt once even when no cache is produced',
    () async {
      final requested = await weather.preloadWeather(
        List.generate(20, (i) => view('$i', start: today)),
        tableName: TableNames.recommendEvents,
      );
      expect(requested, isTrue);
      expect(weather.calls, ['Taipei']);
    },
  );
  test('different locations are still fetched independently', () async {
    await weather.preloadWeather([
      view('a', start: today),
      view('b', start: today, location: 'Kaohsiung'),
    ], tableName: TableNames.recommendEvents);
    expect(weather.calls, ['Taipei', 'Kaohsiung']);
  });
  test('later batches can retry a failed location', () async {
    for (var i = 0; i < 2; i++) {
      await weather.preloadWeather([
        view('$i', start: today),
      ], tableName: TableNames.recommendEvents);
    }
    expect(weather.calls, ['Taipei', 'Taipei']);
  });
  test('missing, past and distant event dates are skipped safely', () async {
    await weather.preloadWeather([
      view('missing'),
      view('past', start: today.subtract(const Duration(days: 1))),
      view('future', start: today.add(const Duration(days: 7))),
      view('eligible', start: today, location: 'eligible'),
    ], tableName: TableNames.recommendEvents);
    expect(weather.calls, ['eligible']);
  });
  test('ongoing events are eligible until their end date', () async {
    await weather.preloadWeather([
      view(
        'ongoing',
        start: today.subtract(const Duration(days: 10)),
        end: today,
      ),
    ], tableName: TableNames.calendarEvents);
    expect(weather.calls, ['Taipei']);
  });
  test('attractions remain eligible without dates', () async {
    await weather.preloadWeather([
      view('place'),
    ], tableName: TableNames.recommendPlaces);
    expect(weather.calls, ['Taipei']);
  });
  test('empty locations and hidden child locations are skipped', () async {
    expect(
      await weather.preloadWeather([
        view('empty', start: today, location: ''),
        view('hidden', start: today, hasLocation: false),
      ], tableName: TableNames.recommendEvents),
      isFalse,
    );
    expect(weather.calls, isEmpty);
  });
  test('valid cache prevents another weather lookup', () async {
    store.cache['Taipei'] = WeatherCache(
      data: [],
      expiresAt: DateTime.now().add(const Duration(hours: 1)),
    );
    expect(
      await weather.preloadWeather([
        view('a', start: today),
      ], tableName: TableNames.recommendEvents),
      isFalse,
    );
    expect(weather.calls, isEmpty);
  });
  test('expired cache is removed and permits one attempt', () async {
    store.cache['Taipei'] = WeatherCache(
      data: [],
      expiresAt: DateTime.now().subtract(const Duration(seconds: 1)),
    );
    await weather.preloadWeather([
      view('a', start: today),
      view('b', start: today),
    ], tableName: TableNames.recommendEvents);
    expect(weather.calls, ['Taipei']);
    expect(store.cache.containsKey('Taipei'), isFalse);
  });
  test('direct loads safely reject missing or out-of-window dates', () async {
    final service = ServiceWeather();
    for (final start in [
      null,
      today.subtract(const Duration(days: 1)),
      today.add(const Duration(days: 7)),
    ]) {
      final event = view('a', start: start);
      expect(
        await service.loadWeather(
          event: event,
          hasLocation: true,
          locationDisplay: 'Taipei',
          startDate: start,
          endDate: null,
          tableName: TableNames.recommendEvents,
        ),
        isNull,
      );
    }
  });
  test(
    'ineligible first card does not prevent an eligible same-location card',
    () async {
      await weather.preloadWeather([
        view('first', start: today.add(const Duration(days: 9))),
        view('second', start: today),
      ], tableName: TableNames.recommendEvents);
      expect(weather.calls, ['Taipei']);
    },
  );
}
