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

/// Follows history cursors until a page contributes at least one new row.
///
/// A retained/reserved row may be returned again by an older window, and a
/// sparse date window can legitimately contain no visible rows. Neither case
/// should require another tap from the user.
Future<ModelRecordHistoryPage<T>?> readNextNonDuplicateHistoryPage<T>({
  required DateTime cursor,
  required Iterable<String> existingIds,
  required String Function(T row) idOf,
  required Future<ModelRecordHistoryPage<T>> Function(DateTime cursor) read,
  bool Function()? shouldContinue,
}) async {
  final knownIds = existingIds.toSet();
  var current = cursor;
  final visited = <DateTime>{};
  while (visited.add(current.toUtc())) {
    if (shouldContinue?.call() == false) return null;
    final page = await read(current);
    if (shouldContinue?.call() == false) return null;
    final rows = <T>[
      for (final row in page.rows)
        if (knownIds.add(idOf(row))) row,
    ];
    if (rows.isNotEmpty || page.nextDate == null) {
      return ModelRecordHistoryPage<T>(
        rows: rows,
        total: page.total,
        nextBefore: page.nextBefore,
        nextDate: page.nextDate,
      );
    }
    final next = page.nextDate!;
    if (!next.isBefore(current)) {
      throw const FormatException('Ledger history cursor did not move back');
    }
    current = next;
  }
  throw const FormatException('Ledger history cursor repeated');
}
