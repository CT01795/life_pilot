import 'package:flutter/material.dart';
import 'package:life_pilot/event/model_event_item.dart';
import 'package:life_pilot/utils/event_city_normalizer.dart';

class WidgetsEventMap extends StatelessWidget {
  final List<EventItem> events;
  final ValueChanged<String> onCitySelected;

  const WidgetsEventMap({
    super.key,
    required this.events,
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
    final counts = <String, int>{};
    for (final event in events) {
      final region = eventRegionKey(event.city);
      if (region.isNotEmpty) {
        counts.update(region, (value) => value + 1, ifAbsent: () => 1);
      }
    }
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
                              left: constraints.maxWidth * position.dx - 15,
                              top: constraints.maxHeight * position.dy - 15,
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
        color: const Color(0xFFE53935),
        elevation: 5,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () => onCitySelected(entry.key),
          child: SizedBox.square(
            dimension: 30,
            child: Center(
              child: Text(
                '${entry.value}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String eventRegionKey(String city) {
  final rawCity = city.replaceAll('\u200B', '').trim();
  if (rawCity.isEmpty) return '';
  final normalized = EventCityNormalizer.normalize(rawCity);
  return WidgetsEventMap._positions.containsKey(normalized)
      ? normalized
      : rawCity;
}
