import 'package:life_pilot/utils/const.dart';
import 'package:life_pilot/utils/record_row_utils.dart';
import 'package:life_pilot/utils/value_parser.dart';

/// Local account selection and totals only; no IO, images, auth or UI state.
class ModelLocalAccountList {
  static List<RecordRow> selectAccounts({
    required Iterable<RecordRow> accounts,
    String? category,
  }) => List<RecordRow>.unmodifiable(
    _selectAccounts(accounts, category: category),
  );

  static ModelLocalAccountList fromIndexedTotals({
    required Iterable<RecordRow> accounts,
    required Map<(String, String?), num> totals,
    required bool points,
  }) {
    final rows = List<RecordRow>.unmodifiable(accounts);
    return ModelLocalAccountList._(rows, {
      for (final row in rows)
        (
          parseStringValue(row[Fields.id]),
          points ? null : parseStringValue(row['main_currency']),
        ): totals[(
              parseStringValue(row[Fields.id]),
              points ? null : parseStringValue(row['main_currency']),
            )] ??
            0,
    }, !points);
  }

  final List<RecordRow> rows;
  final Map<(String, String?), num> _totals;
  final bool _byCurrency;
  ModelLocalAccountList._(
    List<RecordRow> rows,
    Map<(String, String?), num> totals,
    this._byCurrency,
  ) : rows = List.unmodifiable(rows),
      _totals = Map.unmodifiable(totals);

  num totalFor(RecordRow account) =>
      _totals[(
        parseStringValue(account[Fields.id]),
        _byCurrency ? parseStringValue(account['main_currency']) : null,
      )] ??
      0;

  static List<RecordRow> _selectAccounts(
    Iterable<RecordRow> accounts, {
    required String? category,
  }) {
    var rows = accounts
        .where(
          (row) =>
              row[Fields.isValid] == true &&
              (category == null ||
                  parseStringValue(row['category']) == category),
        )
        .toList();
    return rows;
  }
}
