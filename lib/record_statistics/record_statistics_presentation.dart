import 'package:life_pilot/record_statistics/model_record_statistics.dart';
import 'package:life_pilot/record_statistics/record_statistics_formats.dart';

/// View-ready text for one immutable series, formatter and current year.
/// Owned by the page, never shared across users or retained in the domain model.
class RecordStatisticsPresentation {
  final RecordStatisticsSeries _series;
  final RecordStatisticsFormats _formats;
  final int _currentYear;
  final List<RecordStatisticsDisplayRow> rows;

  RecordStatisticsPresentation({
    required RecordStatisticsSeries series,
    required RecordStatisticsFormats formats,
    required int currentYear,
  }) : _series = series,
       _formats = formats,
       _currentYear = currentYear,
       rows = List.unmodifiable([
         for (var i = 0; i < series.months.length; i++)
           RecordStatisticsDisplayRow(
             series.months[i].month,
             series.values[i],
             formats.month(series.months[i].month),
             formats.axisMonth(
               series.months[i].month,
               currentYear: currentYear,
             ),
             formats.value(series.values[i]),
           ),
       ]);

  bool matches({
    required RecordStatisticsSeries series,
    required RecordStatisticsFormats formats,
    required int currentYear,
  }) =>
      identical(_series, series) &&
      identical(_formats, formats) &&
      _currentYear == currentYear;
}

class RecordStatisticsDisplayRow {
  final DateTime month;
  final num value;
  final String monthLabel;
  final String axisLabel;
  final String valueLabel;

  const RecordStatisticsDisplayRow(
    this.month,
    this.value,
    this.monthLabel,
    this.axisLabel,
    this.valueLabel,
  );
}
