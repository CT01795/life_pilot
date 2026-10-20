import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:life_pilot/auth/controller_auth.dart';
import 'package:life_pilot/event/controller_content_performance.dart';
import 'package:life_pilot/event/widgets_content_performance_overview.dart';
import 'package:life_pilot/event/widgets_content_performance_card.dart';
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
                              loc.statisticsNoData,
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      );
                    }
                    return WidgetsContentPerformanceOverview(data: data);
                  }
                  final item = data!.items[index - 2];
                  return WidgetsContentPerformanceCard(
                    item: item,
                    performance: data,
                    expansionKey: ValueKey((
                      controller.selectedMonth,
                      item.id,
                      index,
                    )),
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
