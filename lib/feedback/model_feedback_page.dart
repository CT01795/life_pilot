import 'package:life_pilot/feedback/model_feedback.dart';

class FeedbackCursor {
  const FeedbackCursor(this.createdAt, this.id);
  final DateTime? createdAt;
  final int id;
}

class FeedbackPage {
  const FeedbackPage({required this.rows, required this.hasMore, this.cursor});
  final List<ModelFeedback> rows;
  final bool hasMore;
  final FeedbackCursor? cursor;
  static const size = 50;

  factory FeedbackPage.fromRows(List<Map<String, dynamic>> raw) {
    final visible = raw.take(size).toList(growable: false);
    FeedbackCursor? cursor;
    if (visible.isNotEmpty) {
      final last = visible.last, id = visible.last['id'];
      final date = last['created_at'];
      if (id is! int ||
          (date != null &&
              (date is! String || DateTime.tryParse(date) == null))) {
        throw const FormatException('Invalid feedback page cursor');
      }
      cursor = FeedbackCursor(
        date == null ? null : DateTime.parse(date as String),
        id,
      );
    }
    return FeedbackPage(
      rows: List.unmodifiable(visible.map(ModelFeedback.fromMap)),
      hasMore: raw.length > size,
      cursor: cursor,
    );
  }
}

typedef FeedbackPageLoader =
    Future<FeedbackPage> Function({
      required Set<String> statuses,
      FeedbackCursor? before,
    });
