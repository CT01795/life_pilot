import 'package:flutter/material.dart';
import 'package:life_pilot/utils/const.dart';

class RecordCategoryFilterOption {
  const RecordCategoryFilterOption({required this.value, required this.label});

  final String? value;
  final String label;
}

class RecordExplorerMetric {
  const RecordExplorerMetric({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;
}

class WidgetsRecordExplorer extends StatefulWidget {
  const WidgetsRecordExplorer({
    super.key,
    required this.searchController,
    required this.searchHint,
    required this.clearTooltip,
    required this.categories,
    required this.selectedCategory,
    required this.onSearchChanged,
    required this.onCategorySelected,
    required this.metrics,
  });

  final TextEditingController searchController;
  final String searchHint;
  final String clearTooltip;
  final List<RecordCategoryFilterOption> categories;
  final String? selectedCategory;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String?> onCategorySelected;
  final List<RecordExplorerMetric> metrics;

  @override
  State<WidgetsRecordExplorer> createState() => _WidgetsRecordExplorerState();
}

class _WidgetsRecordExplorerState extends State<WidgetsRecordExplorer> {
  final ScrollController _categoryScrollController = ScrollController();
  final ScrollController _metricScrollController = ScrollController();

  @override
  void dispose() {
    _categoryScrollController.dispose();
    _metricScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.outlineVariant),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: widget.searchController,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  isDense: true,
                  hintText: widget.searchHint,
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: widget.searchController.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: widget.clearTooltip,
                          onPressed: () {
                            widget.searchController.clear();
                            widget.onSearchChanged('');
                          },
                          icon: const Icon(Icons.clear),
                        ),
                ),
                onChanged: widget.onSearchChanged,
              ),
              Gaps.h8,
              _RecordHorizontalLane(
                controller: _categoryScrollController,
                child: Row(
                  children: [
                    for (final category in widget.categories) ...[
                      FilterChip(
                        selected: widget.selectedCategory == category.value,
                        label: Text(category.label),
                        onSelected: (_) =>
                            widget.onCategorySelected(category.value),
                      ),
                      Gaps.w8,
                    ],
                  ],
                ),
              ),
              Gaps.h8,
              LayoutBuilder(
                builder: (context, constraints) {
                  if (constraints.maxWidth < 420) {
                    return _RecordHorizontalLane(
                      controller: _metricScrollController,
                      child: Row(
                        children: [
                          for (
                            var index = 0;
                            index < widget.metrics.length;
                            index++
                          ) ...[
                            if (index > 0) Gaps.w8,
                            SizedBox(
                              width: 128,
                              child: _RecordMetricTile(
                                metric: widget.metrics[index],
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  }
                  final width = (constraints.maxWidth - 16) / 3;
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (
                        var index = 0;
                        index < widget.metrics.length;
                        index++
                      ) ...[
                        if (index > 0) Gaps.w8,
                        SizedBox(
                          width: width,
                          child: _RecordMetricTile(
                            metric: widget.metrics[index],
                          ),
                        ),
                      ],
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Keep a single scrollbar OUTSIDE the text viewport, after every label/value.
/// Desktop's automatic scrollbar is disabled only for this explicit lane.
class _RecordHorizontalLane extends StatelessWidget {
  const _RecordHorizontalLane({required this.controller, required this.child});

  final ScrollController controller;
  final Widget child;

  @override
  Widget build(BuildContext context) => MediaQuery.removePadding(
    context: context,
    // This lane is inside the page, not at the physical screen edge. The
    // scrollbar's inherited bottom safe area would move its thumb over text.
    removeBottom: true,
    child: Scrollbar(
      controller: controller,
      thumbVisibility: true,
      thickness: 4,
      scrollbarOrientation: ScrollbarOrientation.bottom,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ScrollConfiguration(
            behavior: ScrollConfiguration.of(
              context,
            ).copyWith(scrollbars: false),
            child: SingleChildScrollView(
              controller: controller,
              scrollDirection: Axis.horizontal,
              child: child,
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    ),
  );
}

class _RecordMetricTile extends StatelessWidget {
  const _RecordMetricTile({required this.metric});

  final RecordExplorerMetric metric;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '${metric.label}: ${metric.value}',
      child: Column(
        children: [
          Icon(metric.icon, size: 20, color: metric.color),
          Gaps.h4,
          Text(
            metric.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelMedium,
          ),
          Gaps.h4,
          Text(
            metric.value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: metric.color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
