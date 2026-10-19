import 'package:life_pilot/event/model_event_item.dart';
import 'package:life_pilot/utils/event_city_normalizer.dart';

/// Normalized display coordinates, shared by grouping and the map view.
/// These are not event geocodes and must not be used for navigation.
const eventRegionPositions = <String, ({double dx, double dy})>{
  '連江': (dx: .17, dy: .11),
  '基隆': (dx: .90, dy: .08),
  '台北': (dx: .65, dy: .06),
  '新北': (dx: .82, dy: .15),
  '桃園': (dx: .66, dy: .11),
  '新竹': (dx: .61, dy: .19),
  '苗栗': (dx: .58, dy: .27),
  '台中': (dx: .55, dy: .35),
  '彰化': (dx: .37, dy: .42),
  '南投': (dx: .57, dy: .45),
  '雲林': (dx: .32, dy: .49),
  '嘉義': (dx: .48, dy: .55),
  '台南': (dx: .38, dy: .63),
  '高雄': (dx: .47, dy: .70),
  '屏東': (dx: .51, dy: .83),
  '宜蘭': (dx: .81, dy: .26),
  '花蓮': (dx: .75, dy: .45),
  '台東': (dx: .69, dy: .72),
  '澎湖': (dx: .11, dy: .54),
  '金門': (dx: .11, dy: .26),
};

class EventRegionData {
  EventRegionData._({
    required this.source,
    required this.counts,
    required this.eventsByRegion,
    required this.sortedRegions,
  });

  factory EventRegionData.fromEvents(List<EventItem> events) {
    final normalizedCities = <String, String>{};
    final eventsByRegion = <String, List<EventItem>>{};
    for (final event in events) {
      final city = event.city;
      final region = normalizedCities.putIfAbsent(
        city,
        () => eventRegionKey(city),
      );
      if (region.isEmpty) continue;
      eventsByRegion.putIfAbsent(region, () => []).add(event);
    }
    final counts = eventsByRegion.map(
      (region, items) => MapEntry(region, items.length),
    );
    final sortedRegions = counts.keys.toList()
      ..sort((left, right) {
        final countComparison = counts[right]!.compareTo(counts[left]!);
        return countComparison != 0 ? countComparison : left.compareTo(right);
      });
    return EventRegionData._(
      source: events,
      counts: counts,
      eventsByRegion: eventsByRegion,
      sortedRegions: sortedRegions,
    );
  }

  final List<EventItem> source;
  final Map<String, int> counts;
  final Map<String, List<EventItem>> eventsByRegion;
  final List<String> sortedRegions;

  List<EventItem> eventsFor(String? region) =>
      region == null ? source : eventsByRegion[region] ?? const [];
}

String eventRegionKey(String city) {
  final rawCity = city.replaceAll('\u200B', '').trim();
  if (rawCity.isEmpty) return '';
  final normalized = EventCityNormalizer.normalize(rawCity);
  return eventRegionPositions.containsKey(normalized) ? normalized : rawCity;
}

/// One projection per page owner. Replace the source list after editing its
/// events, or clear explicitly if the same list is mutated in place.
class ModelEventRegions {
  EventRegionData? _cached;

  EventRegionData select(List<EventItem> events) {
    final cached = _cached;
    if (cached != null && identical(cached.source, events)) return cached;
    return _cached = EventRegionData.fromEvents(events);
  }

  void clear() => _cached = null;
}
