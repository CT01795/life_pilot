import 'package:life_pilot/utils/const.dart';
import 'package:life_pilot/utils/enum.dart';
import 'package:life_pilot/utils/record_row_utils.dart';
import 'package:life_pilot/utils/value_parser.dart';

/// Local account selection and totals only; no IO, images, auth or UI state.
/// Index only displayed accounts, then scan detail values once for all of them.
class ModelLocalAccountList {
  // Weak snapshot keys do not keep old owner/resource lists alive. Cache only
  // requested account totals; a new immutable detail snapshot starts fresh.
  static final _summaryTotals = Expando<Map<(bool, String, String?), num>>();

  /// Read-only detail snapshots share totals between list and exact lookups.
  /// Account selection is recalculated so changed validity/currency is honored.
  static ModelLocalAccountList fromSnapshots({
    required Iterable<RecordRow> accounts,
    required List<RecordRow> details,
    required bool points,
    String? category,
    int? projectLimit,
  }) => _build(
    accounts,
    details,
    category: category,
    projectLimit: projectLimit,
    byCurrency: !points,
    valueOf: points ? parseIntValue : parseNumValue,
    snapshotTotals: _summaryTotals[details] ??= {},
  );

  /// Use only read-only LocalDataStore snapshots. The first lookup retains the
  /// existing one-pass calculation; repeats skip scanning unchanged details.
  static num totalForSnapshot({
    required List<RecordRow> details,
    required RecordRow account,
    required bool points,
  }) {
    if (account[Fields.isValid] != true) return 0;
    final totals = _summaryTotals[details] ??= {};
    final key = (
      points,
      parseStringValue(account[Fields.id]),
      points ? null : parseStringValue(account['main_currency']),
    );
    return totals.putIfAbsent(key, () {
      final projection = points
          ? ModelLocalAccountList.points([account], details)
          : ModelLocalAccountList.accounting([account], details);
      return projection.totalFor(account);
    });
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
    Map<(bool, String, String?), num>? snapshotTotals,
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
    final missing = <(String, String?)>{};
    for (final key in totals.keys) {
      final cached = snapshotTotals?[(!byCurrency, key.$1, key.$2)];
      if (cached == null) {
        missing.add(key);
      } else {
        totals[key] = cached;
      }
    }
    if (missing.isNotEmpty) {
      for (final detail in details) {
        final key = (
          parseStringValue(detail['account_id']),
          byCurrency ? parseStringValue(detail['currency']) : null,
        );
        if (!missing.contains(key)) continue;
        totals[key] = totals[key]! + valueOf(detail['value']);
      }
      // Publish only after a complete scan; a failed read must remain retryable.
      if (snapshotTotals != null) {
        for (final key in missing) {
          snapshotTotals[(!byCurrency, key.$1, key.$2)] = totals[key]!;
        }
      }
    }
    return ModelLocalAccountList._(rows, totals, byCurrency);
  }
}
