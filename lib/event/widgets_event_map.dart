import 'package:flutter/material.dart';
import 'package:life_pilot/event/model_event_item.dart';
import 'package:life_pilot/utils/event_city_normalizer.dart';

class WidgetsEventMap extends StatelessWidget {
  final EventRegionData regionData;
  final ValueChanged<String> onCitySelected;

  const WidgetsEventMap({
    super.key,
    required this.regionData,
    required this.onCitySelected,
  });

  static const _positions = <String, Offset>{
    '連江': Offset(.17, .11),
    '基隆': Offset(.90, .08),
    '台北': Offset(.65, .06),
    '新北': Offset(.82, .15),
    '桃園': Offset(.66, .11),
    '新竹': Offset(.61, .19),
    '苗栗': Offset(.58, .27),
    '台中': Offset(.55, .35),
    '彰化': Offset(.37, .42),
    '南投': Offset(.57, .45),
    '雲林': Offset(.32, .49),
    '嘉義': Offset(.48, .55),
    '台南': Offset(.38, .63),
    '高雄': Offset(.47, .70),
    '屏東': Offset(.51, .83),
    '宜蘭': Offset(.81, .26),
    '花蓮': Offset(.75, .45),
    '台東': Offset(.69, .72),
    '澎湖': Offset(.11, .54),
    '金門': Offset(.11, .26),
  };

  static const _outlyingCities = {'連江', '澎湖', '金門'};

  @override
  Widget build(BuildContext context) {
    final counts = regionData.counts;
    final mapCounts = Map.fromEntries(counts.entries.where(
      (entry) =>
          _positions.containsKey(entry.key) &&
          !_outlyingCities.contains(entry.key),
    ));
    final otherCounts = Map.fromEntries(counts.entries.where(
      (entry) =>
          !_positions.containsKey(entry.key) ||
          _outlyingCities.contains(entry.key),
    ));

    return ColoredBox(
      color: const Color(0xFFE8F7FA),
      child: Column(
        children: [
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints:
                    const BoxConstraints(maxWidth: 520, maxHeight: 680),
                child: AspectRatio(
                  aspectRatio: 1,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return Stack(
                        fit: StackFit.expand,
                        clipBehavior: Clip.hardEdge,
                        children: [
                          Image.asset(
                            'assets/maps/taiwan.png',
                            fit: BoxFit.contain,
                          ),
                          ...mapCounts.entries.map((entry) {
                            final position = _positions[entry.key]!;
                            return Positioned(
                              left: constraints.maxWidth * position.dx - 22,
                              top: constraints.maxHeight * position.dy - 22,
                              child: _countButton(entry),
                            );
                          }),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
          if (otherCounts.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              color: Colors.white.withValues(alpha: .86),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: otherCounts.entries
                    .map(
                      (entry) => ActionChip(
                        avatar: const Icon(Icons.public_rounded, size: 17),
                        label: Text('${entry.key}  ${entry.value}'),
                        onPressed: () => onCitySelected(entry.key),
                      ),
                    )
                    .toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _countButton(MapEntry<String, int> entry) {
    return Tooltip(
      message: '${entry.key} ${entry.value}',
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () => onCitySelected(entry.key),
          child: SizedBox.square(
            dimension: 44,
            child: Center(
              child: Material(
                color: const Color(0xFFE53935),
                elevation: 5,
                shape: const CircleBorder(),
                child: SizedBox.square(
                  dimension: 34,
                  child: Center(
                    child: Text(
                      '${entry.value}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class EventRegionData {
  EventRegionData._({
    required this.source,
    required this.counts,
    required this.eventsByRegion,
    required this.sortedRegions,
  });

  factory EventRegionData.fromEvents(List<EventItem> events) {
    final counts = <String, int>{};
    final eventsByRegion = <String, List<EventItem>>{};
    for (final event in events) {
      final region = eventRegionKey(event.city);
      if (region.isEmpty) continue;
      counts.update(region, (value) => value + 1, ifAbsent: () => 1);
      eventsByRegion.putIfAbsent(region, () => []).add(event);
    }
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
  return WidgetsEventMap._positions.containsKey(normalized)
      ? normalized
      : rawCity;
}
