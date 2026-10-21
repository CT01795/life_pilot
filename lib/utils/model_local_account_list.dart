import 'package:life_pilot/utils/const.dart';
import 'package:life_pilot/utils/enum.dart';
import 'package:life_pilot/utils/record_row_utils.dart';
import 'package:life_pilot/utils/value_parser.dart';

/// Local account selection and totals only; no IO, images, auth or UI state.
/// Index only displayed accounts, then scan detail values once for all of them.
class ModelLocalAccountList {
  final List<RecordRow> rows;
  final Map<(String, String?), num> _totals;
  final bool _byCurrency;
  ModelLocalAccountList._(
    List<RecordRow> rows,
    Map<(String, String?), num> totals,
    this._byCurrency,
  ) : rows = List.unmodifiable(rows),
      _totals = Map.unmodifiable(totals);

  static ModelLocalAccountList accounting(
    Iterable<RecordRow> accounts,
    Iterable<RecordRow> details, {
    String? category,
    int? projectLimit,
  }) => _build(
    accounts,
    details,
    category: category,
    projectLimit: projectLimit,
    byCurrency: true,
    valueOf: parseNumValue,
  );

  static ModelLocalAccountList points(
    Iterable<RecordRow> accounts,
    Iterable<RecordRow> details, {
    String? category,
    int? projectLimit,
  }) => _build(
    accounts,
    details,
    category: category,
    projectLimit: projectLimit,
    byCurrency: false,
    valueOf: parseIntValue,
  );

  num totalFor(RecordRow account) =>
      _totals[(
        parseStringValue(account[Fields.id]),
        _byCurrency ? parseStringValue(account['main_currency']) : null,
      )] ??
      0;

  static ModelLocalAccountList _build(
    Iterable<RecordRow> accounts,
    Iterable<RecordRow> details, {
    required String? category,
    required int? projectLimit,
    required bool byCurrency,
    required num Function(Object?) valueOf,
  }) {
    var rows = accounts
        .where(
          (row) =>
              row[Fields.isValid] == true &&
              (category == null ||
                  parseStringValue(row['category']) == category),
        )
        .toList();
    if (category == null && projectLimit != null) {
      final personal = rows.where(
        (r) => r['category'] == AccountCategory.personal.name,
      );
      final projects =
          rows
              .where((r) => r['category'] == AccountCategory.project.name)
              .toList()
            ..sort(
              (a, b) => parseStringValue(
                b[Fields.createdAt],
              ).compareTo(parseStringValue(a[Fields.createdAt])),
            );
      rows = [...personal, ...projects.take(projectLimit)];
    }
    final totals = <(String, String?), num>{
      for (final row in rows)
        (
          parseStringValue(row[Fields.id]),
          byCurrency ? parseStringValue(row['main_currency']) : null,
        ): 0,
    };
    if (totals.isNotEmpty) {
      for (final detail in details) {
        final key = (
          parseStringValue(detail['account_id']),
          byCurrency ? parseStringValue(detail['currency']) : null,
        );
        final previous = totals[key];
        if (previous == null) continue;
        totals[key] = previous + valueOf(detail['value']);
      }
    }
    return ModelLocalAccountList._(rows, totals, byCurrency);
  }
}
