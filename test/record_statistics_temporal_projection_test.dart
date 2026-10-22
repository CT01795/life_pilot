import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/record_statistics/model_record_statistics.dart';
import 'package:life_pilot/utils/value_parser.dart';

class _CountedDate implements DateTime {
  final DateTime value;
  int calendarReads = 0;
  int comparisons = 0;
  _CountedDate(this.value);
  @override
  DateTime toLocal() => this;
  @override
  bool isBefore(DateTime other) {
    comparisons++;
    return value.isBefore(other);
  }

  @override
  int get year {
    calendarReads++;
    return value.year;
  }

  @override
  int get month {
    calendarReads++;
    return value.month;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('Unexpected date access: ${invocation.memberName}');
}

// Frozen pre-refactor calculation to check all totals and chronological buckets.
ModelRecordStatistics _reference(
  List<Map<String, dynamic>> rows,
  DateTime now,
) {
  final monthStart = DateTime(now.year, now.month);
  final nextMonth = DateTime(now.year, now.month + 1);
  final dayStart = DateTime(now.year, now.month, now.day);
  final nextDay = DateTime(now.year, now.month, now.day + 1);
  final firstMonth = DateTime(now.year, now.month - 11);
  final buckets = List<num>.filled(12, 0);
  num total = 0, month = 0, today = 0, opening = 0;
  var hasData = false;
  for (final row in rows) {
    final date = tryParseDateTimeValue(row['date'], toLocal: true);
    if (date == null) continue;
    if (date.isBefore(nextMonth)) hasData = true;
    final value = parseNumValue(row['value']);
    total += value;
    if (!date.isBefore(monthStart) && date.isBefore(nextMonth)) month += value;
    if (!date.isBefore(dayStart) && date.isBefore(nextDay)) today += value;
    if (date.isBefore(firstMonth)) opening += value;
    final index =
        (date.year - firstMonth.year) * 12 + date.month - firstMonth.month;
    if (index >= 0 && index < 12) buckets[index] += value;
  }
  var cumulative = opening;
  return ModelRecordStatistics(total, month, today, [
    for (var i = 0; i < 12; i++)
      RecordMonthStatistics(
        DateTime(firstMonth.year, firstMonth.month + i),
        buckets[i],
        cumulative += buckets[i],
      ),
  ], hasChartData: hasData);
}

void main() {
  final now = DateTime(2026, 10, 22, 15);
  test(
    'future month contributes to total without reading chart calendar fields',
    () {
      final date = _CountedDate(DateTime(2026, 11));
      final result = ModelRecordStatistics.fromRows([
        {'date': date, 'value': -23.1234},
      ], now: now);
      expect(result.total, -23.1234);
      expect(result.month, 0);
      expect(result.today, 0);
      expect(result.hasChartData, isFalse);
      expect(result.months.every((month) => month.cumulative == 0), isTrue);
      expect(date.calendarReads, 0);
      expect(date.comparisons, 1);
    },
  );

  test(
    'opening history skips day and bucket calculations but remains cumulative',
    () {
      final date = _CountedDate(DateTime(2020));
      final result = ModelRecordStatistics.fromRows([
        {'date': date, 'value': 50},
      ], now: now);
      expect(result.total, 50);
      expect(result.month, 0);
      expect(result.today, 0);
      expect(result.hasChartData, isTrue);
      expect(
        result.months.every(
          (month) => month.net == 0 && month.cumulative == 50,
        ),
        isTrue,
      );
      expect(date.calendarReads, 0);
      expect(date.comparisons, 2);
    },
  );

  test(
    'temporal fast paths match original totals over randomized boundaries',
    () {
      final random = Random(20261022);
      for (var batch = 0; batch < 200; batch++) {
        final current = DateTime(
          2025 + random.nextInt(3),
          1 + random.nextInt(12),
          1 + random.nextInt(28),
        );
        final edges = [
          DateTime(current.year, current.month - 11),
          DateTime(current.year, current.month),
          DateTime(current.year, current.month, current.day),
          DateTime(current.year, current.month, current.day + 1),
          DateTime(current.year, current.month + 1),
        ];
        final rows = <Map<String, dynamic>>[
          for (final edge in edges)
            for (final micros in [-1, 0, 1])
              {
                'date': edge
                    .add(Duration(microseconds: micros))
                    .toUtc()
                    .toIso8601String(),
                'value': micros,
              },
          for (var i = 0; i < 80; i++)
            {
              'date': i % 13 == 0
                  ? 'invalid'
                  : DateTime(
                      current.year,
                      current.month - 24 + random.nextInt(40),
                      1 + random.nextInt(28),
                    ).toUtc(),
              'value': i % 5 == 0 ? '-23.1234' : random.nextInt(2000) - 1000,
            },
        ];
        final expected = _reference(rows, current);
        final result = ModelRecordStatistics.fromRows(rows, now: current);
        expect(
          [result.total, result.month, result.today, result.hasChartData],
          [
            expected.total,
            expected.month,
            expected.today,
            expected.hasChartData,
          ],
          reason: 'batch $batch',
        );
        expect(
          result.months.map((m) => (m.month, m.net, m.cumulative)),
          expected.months.map((m) => (m.month, m.net, m.cumulative)),
          reason: 'batch $batch',
        );
      }
    },
  );
}
