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

class WidgetsRecordExplorer extends StatelessWidget {
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
                controller: searchController,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  isDense: true,
                  hintText: searchHint,
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: searchController.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: clearTooltip,
                          onPressed: () {
                            searchController.clear();
                            onSearchChanged('');
                          },
                          icon: const Icon(Icons.clear),
                        ),
                ),
                onChanged: onSearchChanged,
              ),
              Gaps.h8,
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final category in categories) ...[
                      FilterChip(
                        selected: selectedCategory == category.value,
                        label: Text(category.label),
                        onSelected: (_) => onCategorySelected(category.value),
                      ),
                      Gaps.w8,
                    ],
                  ],
                ),
              ),
              Gaps.h8,
              LayoutBuilder(
                builder: (context, constraints) {
                  final width = (constraints.maxWidth - 16) / 3;
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (var index = 0; index < metrics.length; index++) ...[
                        if (index > 0) Gaps.w8,
                        SizedBox(
                          width: width,
                          child: _RecordMetricTile(metric: metrics[index]),
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
