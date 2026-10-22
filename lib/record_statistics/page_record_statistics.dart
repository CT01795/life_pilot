import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:life_pilot/auth/controller_auth.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/record_statistics/controller_record_statistics.dart';
import 'package:life_pilot/record_statistics/model_record_statistics.dart';
import 'package:life_pilot/record_statistics/service_record_statistics.dart';
import 'package:life_pilot/record_statistics/record_statistics_formats.dart';

class PageRecordStatistics extends StatefulWidget {
  final String accountId;
  final String accountName;
  final RecordStatisticsKind kind;
  final String? currency;
  final ServiceRecordStatistics? service;
  const PageRecordStatistics({
    super.key,
    required this.accountId,
    required this.accountName,
    required this.kind,
    this.currency,
    this.service,
  });
  @override
  State<PageRecordStatistics> createState() => _PageRecordStatisticsState();
}

class _PageRecordStatisticsState extends State<PageRecordStatistics> {
  late final ControllerRecordStatistics controller;
  bool cumulative = true;
  @override
  void initState() {
    super.initState();
    controller = ControllerRecordStatistics(
      auth: context.read<ControllerAuth>(),
      accountId: widget.accountId,
      kind: widget.kind,
      currency: widget.currency,
      history: true,
      service: widget.service,
    );
    unawaited(controller.load());
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final formats = RecordStatisticsFormats.forLocale(loc.localeName);
    return Scaffold(
      appBar: AppBar(title: Text(loc.recordStatistics)),
      body: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          final currentYear = DateTime.now().year;
          final data = controller.data;
          if (controller.loading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (data == null) {
            return Center(
              child: TextButton(
                onPressed: () => controller.load(),
                child: Text(loc.retry),
              ),
            );
          }
          if (!data.hasChartData) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(loc.statisticsNoData, textAlign: TextAlign.center),
              ),
            );
          }
          final series = data.series(cumulative: cumulative);
          final months = series.months;
          final values = series.values;
          final maximum = series.maximum;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                widget.accountName,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              Text(
                '${loc.lastTwelveMonths} ${widget.currency ?? loc.pointsUnit}',
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ChoiceChip(
                    label: Text(loc.cumulativeMonthly),
                    selected: cumulative,
                    onSelected: (_) => setState(() => cumulative = true),
                  ),
                  ChoiceChip(
                    label: Text(loc.monthlyNet),
                    selected: !cumulative,
                    onSelected: (_) => setState(() => cumulative = false),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: math.max(840, constraints.maxWidth),
                    height: 320,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        for (var i = 0; i < 12; i++)
                          Expanded(
                            child: Tooltip(
                              message:
                                  '${formats.month(months[i].month)}: ${formats.value(values[i])}',
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(
                                    height: 44,
                                    child: Text(
                                      key: ValueKey((
                                        'record-chart-value',
                                        months[i].month,
                                      )),
                                      formats.value(values[i]),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: values[i] < 0
                                            ? Theme.of(
                                                context,
                                              ).colorScheme.error
                                            : null,
                                      ),
                                    ),
                                  ),
                                  SizedBox(
                                    height: 180,
                                    child: Stack(
                                      children: [
                                        const Positioned(
                                          left: 0,
                                          right: 0,
                                          top: 89,
                                          child: Divider(height: 1),
                                        ),
                                        Positioned(
                                          left: 12,
                                          right: 12,
                                          top: values[i] < 0
                                              ? 90
                                              : 90 -
                                                    88 *
                                                        values[i].abs() /
                                                        maximum,
                                          height:
                                              88 * values[i].abs() / maximum,
                                          child: ColoredBox(
                                            color: values[i] < 0
                                                ? Theme.of(
                                                    context,
                                                  ).colorScheme.error
                                                : Theme.of(
                                                    context,
                                                  ).colorScheme.primary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    key: ValueKey((
                                      'record-axis-month',
                                      months[i].month,
                                    )),
                                    formats.axisMonth(
                                      months[i].month,
                                      currentYear: currentYear,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 18),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              for (var i = 0; i < 12; i++)
                ListTile(
                  key: ValueKey(('record-month-row', months[i].month)),
                  title: Text(formats.month(months[i].month)),
                  subtitle: Text(
                    formats.value(values[i]),
                    style: TextStyle(
                      color: values[i] < 0
                          ? Theme.of(context).colorScheme.error
                          : null,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
