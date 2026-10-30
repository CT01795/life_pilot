import 'package:life_pilot/utils/value_parser.dart';

/// Transport projection for charts only, never for ledger/export detail pages.
/// It preserves opening balance, this month's net, today's net and future total
/// using at most fifteen signed buckets instead of all historical records.
class ModelRecordStatisticsBuckets {
  const ModelRecordStatisticsBuckets._();
  static List<Map<String, dynamic>> toRows(
    Map<String, dynamic> json,
    DateTime now,
  ) {
    final months = json['months'];
    if (months is! List || months.length != 12) {
      throw const FormatException('Expected twelve monthly totals');
    }
    final first = DateTime(now.year, now.month - 11);
    final next = DateTime(now.year, now.month + 1);
    final result = <Map<String, dynamic>>[];
    void add(DateTime date, num value) {
      if (value != 0) {
        result.add({'date': date.toIso8601String(), 'value': value});
      }
    }

    add(DateTime(first.year, first.month, 0), parseNumValue(json['opening']));
    for (var i = 0; i < 12; i++) {
      final net = parseNumValue(months[i]);
      if (i < 11) {
        add(DateTime(first.year, first.month + i), net);
        continue;
      }
      final today = parseNumValue(json['today']);
      // Never attribute the whole month to today when today is the first day.
      add(DateTime(now.year, now.month, now.day == 1 ? 2 : 1), net - today);
      add(DateTime(now.year, now.month, now.day), today);
    }
    // Zero-value/offsetting records are real history, not an empty chart.
    if (json['has_history'] == true && result.isEmpty) {
      result.add({'date': first.toIso8601String(), 'value': 0});
    }
    add(next, parseNumValue(json['future']));
    return result;
  }
}
