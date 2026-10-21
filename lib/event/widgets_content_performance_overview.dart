import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:life_pilot/event/model_content_performance.dart';
import 'package:life_pilot/event/content_performance_metric_presentation.dart';
import 'package:life_pilot/l10n/app_localizations.dart';

class WidgetsContentPerformanceOverview extends StatelessWidget {
  final ModelContentPerformance data;
  const WidgetsContentPerformanceOverview({super.key, required this.data});
  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final format = NumberFormat.decimalPattern(loc.localeName);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          loc.performanceOverview,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 720
                ? 3
                : constraints.maxWidth >= 280 &&
                      MediaQuery.textScalerOf(context).scale(14) < 24
                ? 2
                : 1;
            final width = (constraints.maxWidth - (columns - 1) * 12) / columns;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final value in data.visibleMetrics)
                  SizedBox(
                    width: width,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: theme.colorScheme.outlineVariant,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              value.metric.icon,
                              color: theme.colorScheme.primary,
                              size: 22,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              format.format(value.count),
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              value.metric.label(loc),
                              style: theme.textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 28),
        Text(
          '${loc.performanceContents} · ${data.rows.length}',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}
