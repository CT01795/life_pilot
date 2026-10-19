import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:life_pilot/auth/controller_auth.dart';
import 'package:life_pilot/event/controller_content_performance.dart';
import 'package:life_pilot/event/model_content_performance.dart';
import 'package:life_pilot/event/service_content_performance.dart';
import 'package:life_pilot/event/widgets_performance_month_picker.dart';
import 'package:life_pilot/l10n/app_localizations.dart';

class PageContentPerformance extends StatefulWidget {
  final bool attractions;
  final ServiceContentPerformance? service;
  const PageContentPerformance({
    super.key,
    required this.attractions,
    this.service,
  });
  @override
  State<PageContentPerformance> createState() => _PageContentPerformanceState();
}

class _PageContentPerformanceState extends State<PageContentPerformance> {
  late final ControllerContentPerformance controller;
  final _search = TextEditingController();
  @override
  void initState() {
    super.initState();
    controller = ControllerContentPerformance(
      auth: context.read<ControllerAuth>(),
      attractions: widget.attractions,
      service: widget.service,
    );
    unawaited(controller.load());
  }

  @override
  void dispose() {
    controller.dispose();
    _search.dispose();
    super.dispose();
  }

  Future<void> _selectMonth() async {
    FocusScope.of(context).unfocus();
    final month = await showPerformanceMonthPicker(
      context,
      controller.selectedMonth ?? DateTime.now(),
    );
    if (mounted && month != null) {
      await controller.selectMonth(month, keyword: _search.text);
    }
  }

  Future<void> _submitSearch(String value) {
    FocusScope.of(context).unfocus();
    return controller.search(value);
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final format = NumberFormat.decimalPattern(loc.localeName);
    final labels = [
      loc.vendorAnalyticsPageViews,
      loc.vendorAnalyticsCardClicks,
      loc.vendorAnalyticsRegistrationClicks,
      loc.vendorAnalyticsSaves,
      loc.vendorAnalyticsLikes,
      loc.vendorAnalyticsDislikes,
    ];
    const icons = [
      Icons.visibility_outlined,
      Icons.directions_outlined,
      Icons.how_to_reg_outlined,
      Icons.bookmark_border,
      Icons.thumb_up_alt_outlined,
      Icons.thumb_down_alt_outlined,
    ];
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.attractions
              ? loc.attractionPerformance
              : loc.activityPerformance,
        ),
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1080),
          child: AnimatedBuilder(
            animation: controller,
            builder: (context, _) {
              final data = controller.data;
              final month = controller.selectedMonth;
              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                itemCount: 2 + (data?.rows.length ?? 0),
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            loc.performanceHideZeroHint,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 12,
                            runSpacing: 10,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              ChoiceChip(
                                label: Text(loc.performanceActive),
                                selected:
                                    month == null ||
                                    (month.year == DateTime.now().year &&
                                        month.month == DateTime.now().month),
                                onSelected: (_) => controller.selectMonth(
                                  null,
                                  keyword: _search.text,
                                ),
                              ),
                              OutlinedButton.icon(
                                onPressed: _selectMonth,
                                icon: const Icon(Icons.calendar_month_outlined),
                                label: Text(
                                  month == null
                                      ? loc.performanceExpiryMonth
                                      : '${loc.performanceExpiryMonth} · ${DateFormat.yMMM(loc.localeName).format(month)}',
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          ValueListenableBuilder<TextEditingValue>(
                            valueListenable: _search,
                            builder: (context, value, _) => TextField(
                              controller: _search,
                              textInputAction: TextInputAction.search,
                              onSubmitted: _submitSearch,
                              decoration: InputDecoration(
                                labelText: loc.search,
                                hintText: loc.performanceSearchHint,
                                filled: true,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                suffixIcon: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (value.text.isNotEmpty)
                                      IconButton(
                                        tooltip: loc.clear,
                                        icon: const Icon(Icons.clear),
                                        onPressed: () {
                                          _search.clear();
                                          controller.search('');
                                        },
                                      ),
                                    IconButton(
                                      tooltip: loc.search,
                                      icon: const Icon(Icons.search),
                                      onPressed: () =>
                                          _submitSearch(_search.text),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            loc.performancePeriodHint,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                  if (index == 1) {
                    if (controller.loading) {
                      return const Padding(
                        padding: EdgeInsets.all(48),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    if (controller.error != null || data == null) {
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              controller.error is TimeoutException
                                  ? loc.performanceTimeout
                                  : loc.dashboardLoadFailed,
                            ),
                            TextButton.icon(
                              onPressed: controller.load,
                              icon: const Icon(Icons.refresh),
                              label: Text(loc.retry),
                            ),
                          ],
                        ),
                      );
                    }
                    if (data.rows.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 48),
                        child: Column(
                          children: [
                            Icon(
                              Icons.query_stats,
                              size: 48,
                              color: theme.colorScheme.outline,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              loc.noInfoAvailable,
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      );
                    }
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
                                      MediaQuery.textScalerOf(
                                            context,
                                          ).scale(14) <
                                          24
                                ? 2
                                : 1;
                            final width =
                                (constraints.maxWidth - (columns - 1) * 12) /
                                columns;
                            return Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: [
                                for (
                                  var i = 0;
                                  i < contentPerformanceColumns.length;
                                  i++
                                )
                                  if (data.totals[contentPerformanceColumns[i]] !=
                                      0)
                                    SizedBox(
                                      width: width,
                                      child: DecoratedBox(
                                        decoration: BoxDecoration(
                                          color: theme
                                              .colorScheme
                                              .surfaceContainerLow,
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                          border: Border.all(
                                            color: theme
                                                .colorScheme
                                                .outlineVariant,
                                          ),
                                        ),
                                        child: Padding(
                                          padding: const EdgeInsets.all(16),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Icon(
                                                icons[i],
                                                color:
                                                    theme.colorScheme.primary,
                                                size: 22,
                                              ),
                                              const SizedBox(height: 12),
                                              Text(
                                                format.format(
                                                  data.totals[contentPerformanceColumns[i]],
                                                ),
                                                style: theme
                                                    .textTheme
                                                    .headlineSmall
                                                    ?.copyWith(
                                                      fontWeight:
                                                          FontWeight.w700,
                                                    ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                labels[i],
                                                style:
                                                    theme.textTheme.bodyMedium,
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
                  final item = data!.items[index - 2];
                  final starts = item.starts;
                  final ends = item.visibleEndDate;
                  final dateFormat = DateFormat.yMd(loc.localeName);
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
                      key: ValueKey((controller.selectedMonth, item.id, index)),
                      tilePadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
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
                            if (city.isNotEmpty)
                              Text(city, style: theme.textTheme.bodySmall),
                            if (starts != null)
                              Text(
                                '${loc.startDate} · ${dateFormat.format(starts)}',
                                style: theme.textTheme.bodySmall,
                              ),
                            if (ends != null)
                              Text(
                                '${loc.endDate} · ${dateFormat.format(ends)}',
                                style: theme.textTheme.bodySmall,
                              ),
                            if (starts == null && item.ends == null)
                              Text(
                                loc.performanceNoExpiry,
                                style: theme.textTheme.bodySmall,
                              ),
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
                        const Divider(height: 24),
                        for (
                          var i = 0;
                          i < contentPerformanceColumns.length;
                          i++
                        )
                          if (item.counts[i] != 0)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Wrap(
                                    alignment: WrapAlignment.spaceBetween,
                                    spacing: 12,
                                    runSpacing: 4,
                                    children: [
                                      Text(
                                        labels[i],
                                        style: theme.textTheme.bodyMedium,
                                      ),
                                      Text(
                                        format.format(item.counts[i]),
                                        style: theme.textTheme.bodyMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.w700,
                                            ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  LinearProgressIndicator(
                                    minHeight: 5,
                                    borderRadius: BorderRadius.circular(3),
                                    value: (item.counts[i] / item.maximum)
                                        .clamp(0.0, 1.0),
                                    backgroundColor: theme
                                        .colorScheme
                                        .surfaceContainerHighest,
                                    color: theme.colorScheme.primary,
                                  ),
                                ],
                              ),
                            ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}
