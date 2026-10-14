typedef FetchRows = Future<List<dynamic>> Function(int offset, int limit);

/// Fills a requested window even when the server caps each response size.
/// Throws if offsets are ignored, rather than silently declaring end-of-data.
Future<List<dynamic>> readPagedRows({
  required FetchRows fetch,
  required int offset,
  required int limit,
}) async {
  if (offset < 0 || limit < 1) throw ArgumentError('Invalid page range');
  final rows = <dynamic>[];
  final seenIds = <Object>{};
  while (rows.length < limit) {
    final batch = await fetch(offset + rows.length, limit - rows.length);
    if (batch.isEmpty) break;
    for (final row in batch.take(limit - rows.length)) {
      if (row is Map &&
          row['id'] != null &&
          !seenIds.add(row['id'] as Object)) {
        throw StateError(
          'Pagination returned a repeated row; check RPC offset',
        );
      }
      rows.add(row);
    }
  }
  return rows;
}
