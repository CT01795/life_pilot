import 'package:life_pilot/business_plan/model_business_plan.dart';
import 'package:life_pilot/utils/sort_if_needed.dart';

/// List policy only: no service, UI, account state or retained result cache.
class ModelBusinessPlanList {
  /// Keep the already ordered list's relative order; filtering must not sort
  /// or alter the source, and completed snapshots cannot be edited by Views.
  static List<ModelBusinessPlan> visible(
    Iterable<ModelBusinessPlan> source,
    Set<String> statuses,
  ) =>
      List.unmodifiable(source.where((plan) => statuses.contains(plan.status)));

  static int _statusRank(String status) => switch (status) {
    'in_progress' => 0,
    'not_started' => 1,
    _ => 2,
  };

  /// Preserve the last row for each ID and the existing tie comparison policy.
  /// Capture sort keys once per unique plan without modifying source records.
  static List<ModelBusinessPlan> ordered(Iterable<ModelBusinessPlan> source) {
    final unique = <String, ModelBusinessPlan>{
      for (final plan in source) plan.id: plan,
    };
    final ranked = [
      for (final plan in unique.values)
        (plan: plan, rank: _statusRank(plan.status), createdAt: plan.createdAt),
    ];
    sortIfNeeded(ranked, (left, right) {
      final statusOrder = left.rank.compareTo(right.rank);
      return statusOrder != 0
          ? statusOrder
          : right.createdAt.compareTo(left.createdAt);
    });
    return [for (final entry in ranked) entry.plan];
  }
}
