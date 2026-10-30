import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:life_pilot/auth/controller_auth.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/record_statistics/controller_record_statistics.dart';
import 'package:life_pilot/record_statistics/model_record_statistics.dart';
import 'package:life_pilot/record_statistics/record_statistics_formats.dart';
import 'package:life_pilot/record_statistics/page_record_statistics.dart';
import 'package:life_pilot/record_statistics/service_record_statistics.dart';

class WidgetsRecordTotals extends StatefulWidget {
  final String accountId;
  final String accountName;
  final RecordStatisticsKind kind;
  final String? currency;
  final num? total;
  final Object? revision;
  final bool showStatistics;
  final bool monthOnly;
  final ServiceRecordStatistics? service;
  const WidgetsRecordTotals({
    super.key,
    required this.accountId,
    this.accountName = '',
    required this.kind,
    this.currency,
    this.total,
    this.revision,
    this.showStatistics = true,
    this.monthOnly = false,
    this.service,
  });
  @override
  State<WidgetsRecordTotals> createState() => _WidgetsRecordTotalsState();
}

class _WidgetsRecordTotalsState extends State<WidgetsRecordTotals> {
  late ControllerRecordStatistics controller;
  bool _reloadScheduled = false;
  void _create() {
    _reloadScheduled = false;
    controller = ControllerRecordStatistics(
      auth: context.read<ControllerAuth>(),
      accountId: widget.accountId,
      kind: widget.kind,
      currency: widget.currency,
      service: widget.service,
    );
    unawaited(controller.load(knownTotal: widget.total));
  }

  @override
  void initState() {
    super.initState();
    _create();
  }

  @override
  void didUpdateWidget(covariant WidgetsRecordTotals oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.accountId != widget.accountId ||
        oldWidget.kind != widget.kind ||
        oldWidget.currency != widget.currency ||
        oldWidget.service != widget.service) {
      controller.dispose();
      _create();
    } else if (oldWidget.total != widget.total ||
        oldWidget.revision != widget.revision) {
      if (!_reloadScheduled) {
        _reloadScheduled = true;
        final target = controller;
        scheduleMicrotask(() {
          if (!mounted || !identical(target, controller)) return;
          _reloadScheduled = false;
          unawaited(controller.load(force: true, knownTotal: widget.total));
        });
      }
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) {
      final loc = AppLocalizations.of(context)!;
      final points = widget.kind == RecordStatisticsKind.points;
      final formats = RecordStatisticsFormats.forLocale(loc.localeName);
      final data = controller.data;
      String value(num? number) => number == null
          ? '—'
          : '${formats.value(number)} ${points ? loc.pointsUnit : widget.currency ?? ''}'
                .trim();
      Widget row(String label, num? number) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Wrap(
          alignment: WrapAlignment.spaceBetween,
          spacing: 12,
          runSpacing: 4,
          children: [
            Text(label),
            Text(
              value(number),
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: number != null && number < 0
                    ? Theme.of(context).colorScheme.error
                    : null,
              ),
            ),
          ],
        ),
      );
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!widget.monthOnly)
            row(points ? loc.totalPoints : loc.totalIncomeExpense, data?.total),
          row(
            points ? loc.monthlyPoints : loc.monthlyIncomeExpense,
            data?.month,
          ),
          if (!widget.monthOnly)
            row(points ? loc.todayPoints : loc.todayIncomeExpense, data?.today),
          if (controller.loading) const LinearProgressIndicator(),
          if (controller.error != null)
            TextButton.icon(
              onPressed: () => controller.load(),
              icon: const Icon(Icons.refresh),
              label: Text(loc.retry),
            ),
          if (widget.showStatistics)
            Align(
              alignment: Alignment.centerLeft,
              child: Tooltip(
                message: loc.viewCharts,
                child: TextButton.icon(
                  icon: const Icon(Icons.bar_chart),
                  label: Text(loc.recordStatistics),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => PageRecordStatistics(
                        accountId: widget.accountId,
                        accountName: widget.accountName,
                        kind: widget.kind,
                        currency: widget.currency,
                        service: widget.service,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      );
    },
  );
}
