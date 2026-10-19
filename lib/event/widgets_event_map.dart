import 'package:flutter/material.dart';
import 'package:life_pilot/event/model_event_regions.dart';

export 'package:life_pilot/event/model_event_regions.dart'
    show EventRegionData, eventRegionKey;

class WidgetsEventMap extends StatelessWidget {
  final EventRegionData regionData;
  final ValueChanged<String> onCitySelected;

  const WidgetsEventMap({
    super.key,
    required this.regionData,
    required this.onCitySelected,
  });

  static const _positions = eventRegionPositions;

  static const _outlyingCities = {'連江', '澎湖', '金門'};

  @override
  Widget build(BuildContext context) {
    final counts = regionData.counts;
    final mapCounts = Map.fromEntries(
      counts.entries.where(
        (entry) =>
            _positions.containsKey(entry.key) &&
            !_outlyingCities.contains(entry.key),
      ),
    );
    final otherCounts = Map.fromEntries(
      counts.entries.where(
        (entry) =>
            !_positions.containsKey(entry.key) ||
            _outlyingCities.contains(entry.key),
      ),
    );

    return ColoredBox(
      color: const Color(0xFFE8F7FA),
      child: Column(
        children: [
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 520,
                  maxHeight: 680,
                ),
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
