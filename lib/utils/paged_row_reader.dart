typedef FetchRows = Future<List<dynamic>> Function(int offset, int limit);

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
