import 'package:flutter/material.dart';
import 'package:life_pilot/event/content_performance_formats.dart';
import 'package:life_pilot/event/model_content_performance.dart';
import 'package:life_pilot/event/content_performance_metric_presentation.dart';
import 'package:life_pilot/l10n/app_localizations.dart';

class WidgetsContentPerformanceCard extends StatelessWidget {
  final ContentPerformanceItem item;
  final ModelContentPerformance performance;
  final Key expansionKey;
  const WidgetsContentPerformanceCard({
    super.key,
    required this.item,
    required this.performance,
    required this.expansionKey,
  });
  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final starts = item.starts;
    final ends = item.visibleEndDate;
    final formats = ContentPerformanceFormats.forLocale(loc.localeName);
    final city = item.city;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      color: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        key: expansionKey,
        initiallyExpanded: true,
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        title: Text(
          item.name,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (city.isNotEmpty) Text(city, style: theme.textTheme.bodySmall),
              if (starts != null)
                Text(
                  '${loc.startDate} · ${formats.date(starts)}',
                  style: theme.textTheme.bodySmall,
                ),
              if (ends != null)
                Text(
                  '${loc.endDate} · ${formats.date(ends)}',
                  style: theme.textTheme.bodySmall,
                ),
              if (starts == null && item.ends == null)
                Text(loc.performanceNoExpiry, style: theme.textTheme.bodySmall),
              const SizedBox(height: 4),
              Text(
                item.approved
                    ? loc.publishedSubmission
                    : loc.unpublishedSubmission,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          _ContentPerformanceMetrics(item: item, performance: performance),
        ],
      ),
    );
  }
}

/// Compact metric tiles wrap only when their actual text needs more room.
class _ContentPerformanceMetrics extends StatelessWidget {
  final ContentPerformanceItem item;
  final ModelContentPerformance performance;
  const _ContentPerformanceMetrics({
    required this.item,
    required this.performance,
  });
  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final formats = ContentPerformanceFormats.forLocale(loc.localeName);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Divider(height: 24),
        Tooltip(
          message: loc.performanceMetricShareExplanation,
          child: Wrap(
            spacing: 6,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                loc.performanceMetricShareHint,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              Icon(
                Icons.info_outline,
                size: 18,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, constraints) => Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final value in item.visibleMetrics)
                ConstrainedBox(
                  key: ValueKey(('performance-metric', item.id, value.metric)),
                  constraints: BoxConstraints(maxWidth: constraints.maxWidth),
                  child: Tooltip(
                    message: loc.performanceMetricShareLabel(
                      value.metric.label(loc),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 48,
                          height: 40,
                          child: Icon(
                            value.metric.icon,
                            size: 24,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        Text(
                          '${formats.count(value.count)}/${formats.count(performance.totalFor(value.metric))}',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
