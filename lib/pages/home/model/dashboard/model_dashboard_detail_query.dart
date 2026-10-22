import 'package:life_pilot/utils/value_parser.dart';

class ModelDashboardDetailProjection {
  final List<Map<String, dynamic>> previewRows;
  final num todayTotal;

  ModelDashboardDetailProjection(
    List<Map<String, dynamic>> rows,
    this.todayTotal,
  ) : previewRows = List.unmodifiable(rows);
}

/// One read-only scan for today's total and a bounded latest-record preview.
/// Does not sort, clone or decode the complete matching detail list.
class ModelDashboardDetailQuery {
  final String accountId;
  final String? currency;
  final int previewLimit;
  final DateTime start;
  final DateTime end;

  ModelDashboardDetailQuery({
    required DateTime now,
    required this.accountId,
    this.currency,
    this.previewLimit = 5,
  }) : start = DateTime(now.year, now.month, now.day),
       end = DateTime(
         now.year,
         now.month,
         now.day,
       ).add(const Duration(days: 1)) {
    if (previewLimit < 0) {
      throw ArgumentError.value(previewLimit, 'previewLimit');
    }
  }

  ModelDashboardDetailProjection selectAccounting(
    Iterable<Map<String, dynamic>> rows,
  ) => _select(rows, parseNumValue);

  ModelDashboardDetailProjection selectPoints(
    Iterable<Map<String, dynamic>> rows,
  ) => _select(rows, parseIntValue);

  ModelDashboardDetailProjection _select(
    Iterable<Map<String, dynamic>> rows,
    num Function(Object?) valueOf,
  ) {
    final latest = <({Map<String, dynamic> row, String date})>[];
    num total = 0;
    for (final row in rows) {
      if (parseStringValue(row['account_id']) != accountId) continue;
      if (currency != null && parseStringValue(row['currency']) != currency) {
        continue;
      }
      final dateText = parseStringValue(row['date']);
      final date = tryParseDateTimeValue(dateText, toLocal: true);
      if (date == null || date.isBefore(start) || !date.isBefore(end)) continue;
      total += valueOf(row['value']);
      if (previewLimit == 0) continue;
      // Once full, an older/equal key cannot enter the preview. Equal keys
      // follow existing rows, preserving the original source-order tie rule.
      if (latest.length == previewLimit &&
          dateText.compareTo(latest.last.date) <= 0) {
        continue;
      }
      // Preserve the previous local date-string ordering. Keep source order
      // for equal keys, without retaining the rest of today's detail rows.
      var index = 0;
      while (index < latest.length &&
          latest[index].date.compareTo(dateText) >= 0) {
        index++;
      }
      if (index >= previewLimit) continue;
      latest.insert(index, (row: row, date: dateText));
      if (latest.length > previewLimit) latest.removeLast();
    }
    return ModelDashboardDetailProjection(
      latest.map((entry) => entry.row).toList(),
      total,
    );
  }
}
