import 'package:life_pilot/vendor/model_vendor_account.dart';

/// A dashboard snapshot; ordering is independent of widgets and persistence.
class ModelVendorDashboard {
  ModelVendorDashboard({
    required this.metrics,
    required this.status,
    required Iterable<VendorPricingPlan> plans,
  }) : plans = _ordered(plans);

  final VendorContentMetrics metrics;
  final VendorSubscriptionStatus status;
  final List<VendorPricingPlan> plans;

  static List<VendorPricingPlan> _ordered(Iterable<VendorPricingPlan> source) {
    const order = {'free': 0, 'partner': 1, 'growth': 2};
    final result = source.toList()
      ..sort((left, right) {
        final byPlan = (order[left.code] ?? 99).compareTo(
          order[right.code] ?? 99,
        );
        return byPlan != 0
            ? byPlan
            : right.effectiveAt.compareTo(left.effectiveAt);
      });
    return List.unmodifiable(result);
  }
}
