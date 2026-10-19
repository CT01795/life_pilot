import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/event/model_event_item.dart';
import 'package:life_pilot/event/model_event_regions.dart';
import 'package:life_pilot/utils/event_city_normalizer.dart';

class _CountedEvent extends EventItem {
  _CountedEvent(String id, String city) : super(id: id, name: id, city: city);
  int cityReads = 0;
  @override
  String get city {
    cityReads++;
    return super.city;
  }
}

EventItem item(String id, String city) =>
    EventItem(id: id, name: id, city: city);

void main() {
  test('known aliases and invisible whitespace preserve region keys', () {
    const aliases = {
      '臺北市': '台北',
      '  台北\u200B ': '台北',
      'Taipei City': '台北',
      'New Taipei City': '新北',
      'Hsinchu City': '新竹',
      'HS': '新竹',
      '中壢區': '桃園',
      '鼓山區': '高雄',
      '連江縣': '連江',
      '澎湖縣': '澎湖',
      '金門縣': '金門',
    };
    for (final entry in aliases.entries) {
      expect(eventRegionKey(entry.key), entry.value);
    }
  });

  test('unknown and international names retain the full cleaned text', () {
    for (final city in ['Singapore', 'Tokyo', 'Los Angeles', '未知城市']) {
      expect(eventRegionKey(' $city\u200B '), city);
    }
    expect(eventRegionKey(' \u200B '), '');
  });

  test('counts merge aliases and exclude blank city names', () {
    final data = EventRegionData.fromEvents([
      item('a', '台北'),
      item('b', '臺北市'),
      item('c', 'Taipei City'),
      item('d', 'Singapore'),
      item('e', ' '),
      item('f', '\u200B'),
    ]);
    expect(data.counts, {'台北': 3, 'Singapore': 1});
    expect(data.eventsFor('台北').map((e) => e.id), ['a', 'b', 'c']);
    expect(data.eventsFor('missing'), isEmpty);
  });

  test('regions sort by count descending then name ascending', () {
    final data = EventRegionData.fromEvents([
      item('a', 'Tokyo'),
      item('b', 'Singapore'),
      item('c', '台北'),
      item('d', 'Singapore'),
      item('e', 'Tokyo'),
      item('f', '高雄'),
    ]);
    final names = ['台北', '高雄']..sort();
    expect(data.sortedRegions, ['Singapore', 'Tokyo', ...names]);
  });

  test('grouping preserves input order and duplicate records', () {
    final first = item('same', '台北');
    final second = item('same', '臺北市');
    final source = [first, item('other', '高雄'), second, first];
    final data = EventRegionData.fromEvents(source);
    expect(data.counts['台北'], 3);
    expect(data.eventsFor('台北'), [first, second, first]);
    expect(data.eventsFor(null), same(source));
    expect(source.map((e) => e.id), ['same', 'other', 'same', 'same']);
  });

  test('empty input creates empty region data', () {
    final data = EventRegionData.fromEvents([]);
    expect(data.counts, isEmpty);
    expect(data.sortedRegions, isEmpty);
    expect(data.eventsByRegion, isEmpty);
    expect(data.eventsFor(null), isEmpty);
  });

  test('same source reuses grouping without rereading cities', () {
    final event = _CountedEvent('a', '台北');
    final source = [event];
    final model = ModelEventRegions();
    final first = model.select(source);
    for (var i = 0; i < 10; i++) {
      expect(model.select(source), same(first));
    }
    expect(event.cityReads, 1);
  });

  test('replaced source refreshes changed city and appended records', () {
    final event = item('a', '台北');
    final model = ModelEventRegions();
    final first = model.select([event]);
    event.city = '高雄';
    final second = model.select([event, item('b', '高雄')]);
    expect(second, isNot(same(first)));
    expect(second.counts, {'高雄': 2});
  });

  test('explicit clear refreshes in-place source edits', () {
    final source = [item('a', '台北')];
    final model = ModelEventRegions();
    final first = model.select(source);
    source.add(item('b', '高雄'));
    model.clear();
    final second = model.select(source);
    expect(second, isNot(same(first)));
    expect(second.counts, {'台北': 1, '高雄': 1});
  });

  test('different page owners never share region caches', () {
    final source = [item('a', '台北')];
    final first = ModelEventRegions().select(source);
    final second = ModelEventRegions().select(source);
    expect(second, isNot(same(first)));
  });

  test('account source replacement cannot retain previous city groups', () {
    final model = ModelEventRegions();
    model.select([item('same', '台北')]);
    final current = model.select([item('same', 'Tokyo')]);
    expect(current.counts, {'Tokyo': 1});
    expect(current.eventsFor('台北'), isEmpty);
  });

  test('all configured positions remain normalized display coordinates', () {
    expect(eventRegionPositions.length, 20);
    for (final entry in eventRegionPositions.entries) {
      expect(eventRegionKey('${entry.key}市'), entry.key);
      expect(entry.value.dx, inInclusiveRange(0, 1));
      expect(entry.value.dy, inInclusiveRange(0, 1));
    }
  });

  test(
    'grouped results match the previous algorithm for generated batches',
    () {
      final random = Random(1910);
      const cities = [
        '台北',
        '臺北市',
        ' HS ',
        '新竹市',
        'Singapore',
        'Tokyo',
        '',
        '\u200B',
        '台南',
      ];
      for (var batch = 0; batch < 100; batch++) {
        final source = List.generate(
          random.nextInt(200),
          (i) => item('$i', cities[random.nextInt(cities.length)]),
        );
        final counts = <String, int>{};
        final grouped = <String, List<EventItem>>{};
        for (final event in source) {
          final raw = event.city.replaceAll('\u200B', '').trim();
          if (raw.isEmpty) continue;
          final normalized = EventCityNormalizer.normalize(raw);
          final key = eventRegionPositions.containsKey(normalized)
              ? normalized
              : raw;
          counts.update(key, (n) => n + 1, ifAbsent: () => 1);
          grouped.putIfAbsent(key, () => []).add(event);
        }
        final data = EventRegionData.fromEvents(source);
        expect(data.counts, counts);
        expect(data.eventsByRegion, grouped);
      }
    },
  );
}
