import 'package:life_pilot/utils/const.dart';
import 'package:life_pilot/utils/record_row_utils.dart';
import 'package:life_pilot/utils/value_parser.dart';

/// Pure defaults policy. Callers own record selection, IO and UI state.
class ModelRecordEntryDefaults {
  static (bool, String)? accountingDirectionAndCategory(RecordRow? row) =>
      _directionAndCategory(row, zeroIsPositive: false);

  static (bool, String)? pointDirectionAndCategory(RecordRow? row) =>
      _directionAndCategory(row, zeroIsPositive: true);

  static (bool, String)? _directionAndCategory(
    RecordRow? row, {
    required bool zeroIsPositive,
  }) {
    if (row == null) return null;
    final value = parseNumValue(row['value']);
    return (
      zeroIsPositive ? value >= 0 : value > 0,
      parseStringValue(row['primary_category'], fallback: 'uncategorized'),
    );
  }

  /// Same created_at text ordering as the previous local full-list sort.
  /// Retains only the newest matching account; never sorts/mutates the source.
  static String latestAccountCurrency(
    Iterable<RecordRow> rows,
    String category,
  ) {
    RecordRow? latest;
    String? latestCreated;
    for (final row in rows) {
      if (row[Fields.isValid] != true ||
          parseStringValue(row['category']) != category) {
        continue;
      }
      final created = parseStringValue(row[Fields.createdAt]);
      if (latest == null || created.compareTo(latestCreated!) > 0) {
        latest = row;
        latestCreated = created;
      }
    }
    return parseStringValue(latest?['main_currency'], fallback: 'TWD');
  }
}
