import 'package:life_pilot/utils/value_parser.dart';

typedef FetchQuestionRows =
    Future<List<dynamic>> Function(int offset, int limit);

class QuestionPageRows {
  const QuestionPageRows({
    required this.rows,
    required this.totalCount,
    required this.hasMore,
  });
  final List<Map<String, dynamic>> rows;

  /// Exact when provided by RPC, otherwise a lower bound including lookahead.
  final int totalCount;
  final bool hasMore;
}

/// Detects the next page without downloading the entire question bank.
Future<QuestionPageRows> readQuestionPage({
  required FetchQuestionRows fetch,
  required int offset,
  required int limit,
}) async {
  if (offset < 0 || limit < 1) {
    throw ArgumentError('Invalid question page range');
  }
  final raw = await fetch(offset, limit + 1);
  final rows = raw
      .take(limit)
      .map((row) => Map<String, dynamic>.from(row as Map))
      .toList();
  final reportedTotal = raw.isEmpty
      ? null
      : tryParseIntValue((raw.first as Map)['total_count']);
  final knownTotal =
      reportedTotal != null && reportedTotal >= offset + rows.length
      ? reportedTotal
      : null;
  var hasMore =
      raw.length > limit ||
      (knownTotal != null && knownTotal > offset + rows.length);
  // Some deployed RPCs cap their page size. Probe one row beyond a full page
  // when no count or lookahead is available, rather than hiding the button.
  if (!hasMore && knownTotal == null && rows.length == limit) {
    hasMore = (await fetch(offset + rows.length, 1)).isNotEmpty;
  }
  return QuestionPageRows(
    rows: rows,
    totalCount: knownTotal ?? offset + rows.length + (hasMore ? 1 : 0),
    hasMore: hasMore,
  );
}
