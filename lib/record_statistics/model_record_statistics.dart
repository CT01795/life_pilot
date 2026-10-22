import 'package:life_pilot/utils/value_parser.dart';

enum RecordStatisticsKind { accounting, points }

/// Locale-independent chart projection, built once and reused on rebuilds.
class RecordStatisticsSeries {
  final List<RecordMonthStatistics> months;
  final List<num> values;
  final double maximum;
  RecordStatisticsSeries._(this.months, this.values, this.maximum);
  factory RecordStatisticsSeries(
    List<RecordMonthStatistics> chronological, {
    required bool cumulative,
  }) {
    final months = List<RecordMonthStatistics>.unmodifiable(
      chronological.reversed,
    );
    final values = <num>[];
    var maximum = 1.0;
    for (final month in months) {
      final value = cumulative ? month.cumulative : month.net;
      values.add(value);
      if (value.abs() > maximum) maximum = value.abs().toDouble();
    }
    return RecordStatisticsSeries._(months, List.unmodifiable(values), maximum);
  }
}

class RecordMonthStatistics {
  final DateTime month;
  final num net;
  final num cumulative;
  const RecordMonthStatistics(this.month, this.net, this.cumulative);
}

/// Signed ledger values only; retained rows do not bypass date boundaries.
class ModelRecordStatistics {
  final num total;
  final num month;
  final num today;
  final List<RecordMonthStatistics> months;

  /// Opening history counts for cumulative charts. Future months do not.
  /// An actual zero-value record or offsetting records are not an empty result.
  final bool hasChartData;
  ModelRecordStatistics(
    this.total,
    this.month,
    this.today,
    List<RecordMonthStatistics> months, {
    this.hasChartData = true,
  }) : months = List.unmodifiable(months);
  late final RecordStatisticsSeries _cumulative = RecordStatisticsSeries(
    months,
    cumulative: true,
  );
  late final RecordStatisticsSeries _monthly = RecordStatisticsSeries(
    months,
    cumulative: false,
  );
  RecordStatisticsSeries series({required bool cumulative}) =>
      cumulative ? _cumulative : _monthly;
  factory ModelRecordStatistics.fromRows(
    Iterable<Map<String, dynamic>> rows, {
    required DateTime now,
    num? totalOverride,
  }) {
    final monthStart = DateTime(now.year, now.month);
    final nextMonth = DateTime(now.year, now.month + 1);
    final dayStart = DateTime(now.year, now.month, now.day);
    final nextDay = DateTime(now.year, now.month, now.day + 1);
    final firstMonth = DateTime(now.year, now.month - 11);
    final firstMonthNumber = firstMonth.year * 12 + firstMonth.month;
    final totals = List<num>.filled(12, 0);
    num total = 0, month = 0, today = 0, opening = 0;
    var hasChartData = false;
    for (final row in rows) {
      final date = tryParseDateTimeValue(row['date'], toLocal: true);
      if (date == null) continue;
      final beforeNextMonth = date.isBefore(nextMonth);
      if (beforeNextMonth) hasChartData = true;
      final value = parseNumValue(row['value']);
      total += value;
      // Future months contribute only to total. Older opening history does not
      // need month/day checks or a chart bucket index for every retained row.
      if (!beforeNextMonth) continue;
      if (date.isBefore(firstMonth)) {
        opening += value;
        continue;
      }
      if (!date.isBefore(monthStart)) {
        month += value;
        if (!date.isBefore(dayStart) && date.isBefore(nextDay)) today += value;
      }
      final index = date.year * 12 + date.month - firstMonthNumber;
      if (index >= 0 && index < 12) totals[index] += value;
    }
    var cumulative = opening;
    return ModelRecordStatistics(totalOverride ?? total, month, today, [
      for (var i = 0; i < 12; i++)
        RecordMonthStatistics(
          DateTime(firstMonth.year, firstMonth.month + i),
          totals[i],
          cumulative += totals[i],
        ),
    ], hasChartData: hasChartData);
  }
}
