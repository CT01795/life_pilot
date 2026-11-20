import 'dart:convert';

import 'package:life_pilot/vendor/model_vendor_account.dart';
import 'package:life_pilot/event/model_event_item.dart';

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

  ModelVendorDashboard applySubmissionSaved({
    required EventItem? previous,
    required EventItem current,
    required bool attraction,
    required DateTime dayStart,
  }) => _applySubmissionMutation(
    previous: previous,
    current: current,
    attraction: attraction,
    dayStart: dayStart,
  );

  ModelVendorDashboard applySubmissionDeleted({
    required EventItem previous,
    required bool attraction,
    required DateTime dayStart,
  }) => _applySubmissionMutation(
    previous: previous,
    current: null,
    attraction: attraction,
    dayStart: dayStart,
  );

  ModelVendorDashboard withRecentSubmissions(
    Iterable<VendorRecentSubmission> recentSubmissions,
  ) => ModelVendorDashboard(
    metrics: metrics.copyWith(recentSubmissions: recentSubmissions),
    status: status,
    plans: plans,
  );

  ModelVendorDashboard withPlans(Iterable<VendorPricingPlan> updatedPlans) =>
      ModelVendorDashboard(
        metrics: metrics,
        status: status,
        plans: updatedPlans,
      );

  ModelVendorDashboard _applySubmissionMutation({
    required EventItem? previous,
    required EventItem? current,
    required bool attraction,
    required DateTime dayStart,
  }) {
    bool activeForDashboard(EventItem? item) {
      if (item == null) return false;
      final boundary = item.endDate ?? item.startDate;
      return boundary == null || !boundary.isBefore(dayStart);
    }

    bool countedForQuota(EventItem? item) {
      if (item == null) return false;
      final boundary = item.endDate ?? item.startDate;
      return boundary != null && !boundary.isBefore(dayStart);
    }

    int delta(bool Function(EventItem?) matches) =>
        (matches(current) ? 1 : 0) - (matches(previous) ? 1 : 0);
    final publishedDelta = delta((item) => item?.isApproved == true);
    final pendingDelta = delta((item) => item != null && !item.isApproved);
    final activeDelta = delta(activeForDashboard);
    final usageDelta = delta(countedForQuota);
    int imageBytes(EventItem? item) => item?.masterGraphUrl == null
        ? 0
        : utf8.encode(item!.masterGraphUrl!).length;
    final imageBytesDelta = imageBytes(current) - imageBytes(previous);

    return ModelVendorDashboard(
      metrics: metrics.copyWith(
        published: (metrics.published + publishedDelta).clamp(0, 1 << 62),
        pending: (metrics.pending + pendingDelta).clamp(0, 1 << 62),
        activeEvents: attraction
            ? metrics.activeEvents
            : (metrics.activeEvents + activeDelta).clamp(0, 1 << 62),
        activeAttractions: attraction
            ? (metrics.activeAttractions + activeDelta).clamp(0, 1 << 62)
            : metrics.activeAttractions,
      ),
      status: status.copyWith(
        eventUsed: attraction
            ? status.eventUsed
            : (status.eventUsed + usageDelta).clamp(0, 1 << 62),
        attractionUsed: attraction
            ? (status.attractionUsed + usageDelta).clamp(0, 1 << 62)
            : status.attractionUsed,
        imageBytesUsed: (status.imageBytesUsed + imageBytesDelta).clamp(
          0,
          1 << 62,
        ),
      ),
      plans: plans,
    );
  }

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
