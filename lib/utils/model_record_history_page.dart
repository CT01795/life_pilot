/// A complete ledger-history response. The page rows, total and next cursor
/// come from the same snapshot so Controllers never need follow-up probes.
class ModelRecordHistoryPage<T> {
  ModelRecordHistoryPage({
    required List<T> rows,
    required this.total,
    required this.nextBefore,
    required this.nextDate,
  }) : rows = List.unmodifiable(rows);

  final List<T> rows;
  final num total;
  final DateTime nextBefore;
  final DateTime? nextDate;

  bool get hasMore => nextDate != null;
}
