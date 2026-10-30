import 'package:life_pilot/feedback/model_feedback.dart';
import 'package:life_pilot/utils/sort_if_needed.dart';

/// Ordering policy only. Status is mutable, so keys are captured per call,
/// never cached. Preserve row identity and each row's decoded screenshots.
class ModelFeedbackList {
  static int _statusRank(String status) => switch (status) {
    'in_progress' => 0,
    'pending' => 1,
    _ => 2,
  };

  static List<ModelFeedback> ordered(Iterable<ModelFeedback> source) {
    final unique = <int, ModelFeedback>{for (final row in source) row.id: row};
    final ranked = [
      for (final row in unique.values)
        (row: row, rank: _statusRank(row.status), date: row.createdAt),
    ];
    sortIfNeeded(ranked, (left, right) {
      final statusOrder = left.rank.compareTo(right.rank);
      return statusOrder != 0 ? statusOrder : right.date.compareTo(left.date);
    });
    return List.unmodifiable(ranked.map((entry) => entry.row));
  }
}
