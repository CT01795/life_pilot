typedef FetchRows = Future<List<dynamic>> Function(int offset, int limit);

/// Reads complete result sets even when the server caps responses below the
/// requested size. Callers retain query, authorization and timeout ownership.
Future<List<Map<String, dynamic>>> readAllPagedRows({
  required FetchRows fetch,
  int batchSize = 500,
}) async {
  if (batchSize < 1) throw ArgumentError.value(batchSize, 'batchSize');
  final rows = <Map<String, dynamic>>[];
  final seen = <String>{};
  while (true) {
    final batch = await fetch(rows.length, batchSize);
    if (batch.isEmpty) return rows;
    for (final value in batch) {
      final row = Map<String, dynamic>.from(value as Map);
      if (!seen.add(row['id'].toString())) {
        throw StateError('Pagination returned a repeated row; check offset');
      }
      rows.add(row);
    }
  }
}

/// Fills a requested window even when the server caps each response size.
/// Throws if offsets are ignored, rather than silently declaring end-of-data.
Future<List<dynamic>> readPagedRows({
  required FetchRows fetch,
  required int offset,
  required int limit,
  int? initialBatchSize,
  void Function(List<dynamic> rows)? onProgress,
}) async {
  if (offset < 0 || limit < 1) throw ArgumentError('Invalid page range');
  if (initialBatchSize != null && initialBatchSize < 1) {
    throw ArgumentError('Invalid initial batch size');
  }
  final rows = <dynamic>[];
  final seenIds = <Object>{};
  while (rows.length < limit) {
    final remaining = limit - rows.length;
    // Keep the logical page unchanged; only its first network response is
    // smaller, so image-heavy lists can show their first cards sooner.
    final batchLimit =
        rows.isEmpty && initialBatchSize != null && initialBatchSize < remaining
        ? initialBatchSize
        : remaining;
    final batch = await fetch(offset + rows.length, batchLimit);
    if (batch.isEmpty) break;
    for (final row in batch.take(batchLimit)) {
      if (row is Map &&
          row['id'] != null &&
          !seenIds.add(row['id'] as Object)) {
        throw StateError(
          'Pagination returned a repeated row; check RPC offset',
        );
      }
      rows.add(row);
    }
    onProgress?.call(List<dynamic>.unmodifiable(rows));
  }
  return rows;
}
