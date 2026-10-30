import 'package:life_pilot/utils/value_parser.dart';
import 'package:life_pilot/event/model_content_performance.dart';

class VendorPricingPlan {
  const VendorPricingPlan({
    required this.id,
    required this.code,
    required this.versionName,
    required this.effectiveAt,
    required this.quarterlyPriceTwd,
    required this.eventQuota,
    required this.attractionQuota,
    required this.imageMegabytes,
    required this.analyticsDays,
  });

  final String id;
  final String code;
  final String versionName;
  final DateTime effectiveAt;
  final int quarterlyPriceTwd;
  final int eventQuota;
  final int attractionQuota;
  final int imageMegabytes;
  final int analyticsDays;

  factory VendorPricingPlan.fromJson(Map<String, dynamic> json) =>
      VendorPricingPlan(
        id: parseStringValue(
          json['id'],
          fallback: parseStringValue(json['plan_code']),
        ),
        code: parseStringValue(json['plan_code'], fallback: 'free'),
        versionName: parseStringValue(json['version_name']),
        effectiveAt:
            tryParseDateTimeValue(json['effective_at']) ?? DateTime.now(),
        quarterlyPriceTwd: parseIntValue(json['quarterly_price_twd']),
        eventQuota: parseIntValue(json['event_quota']),
        attractionQuota: parseIntValue(json['attraction_quota']),
        imageMegabytes: parseIntValue(json['image_megabytes']),
        analyticsDays: parseIntValue(json['analytics_days']),
      );
}

class VendorSubscriptionStatus {
  const VendorSubscriptionStatus({
    required this.plan,
    required this.status,
    required this.eventUsed,
    required this.attractionUsed,
    required this.imageBytesUsed,
    this.currentPeriodEnd,
  });

  final VendorPricingPlan plan;
  final String status;
  final int eventUsed;
  final int attractionUsed;
  final int imageBytesUsed;
  final DateTime? currentPeriodEnd;

  factory VendorSubscriptionStatus.fromJson(Map<String, dynamic> json) {
    final rawPlan = Map<String, dynamic>.from(
      json['plan'] as Map? ?? const <String, dynamic>{},
    );
    return VendorSubscriptionStatus(
      plan: VendorPricingPlan.fromJson(rawPlan),
      status: parseStringValue(json['status'], fallback: 'active'),
      eventUsed: parseIntValue(json['event_used']),
      attractionUsed: parseIntValue(json['attraction_used']),
      imageBytesUsed: parseIntValue(json['image_bytes_used']),
      currentPeriodEnd: tryParseDateTimeValue(json['current_period_end']),
    );
  }
}

class VendorContentMetrics {
  const VendorContentMetrics({
    required this.published,
    required this.pending,
    required this.activeEvents,
    required this.activeAttractions,
    required this.recentSubmissions,
    required this.performance,
  });

  final int published;
  final int pending;
  final int activeEvents;
  final int activeAttractions;
  final List<VendorRecentSubmission> recentSubmissions;
  final ModelContentPerformance performance;

  factory VendorContentMetrics.fromSummary(Map<String, dynamic> json) =>
      VendorContentMetrics(
        published: parseIntValue(json['published']),
        pending: parseIntValue(json['pending']),
        activeEvents: parseIntValue(json['active_events']),
        activeAttractions: parseIntValue(json['active_attractions']),
        recentSubmissions: List.unmodifiable(
          (json['recent_submissions'] as List).take(5).map((raw) {
            final row = Map<String, dynamic>.from(raw as Map);
            return VendorRecentSubmission(
              id: parseStringValue(row['id']),
              name: parseStringValue(row['name']),
              city: parseStringValue(row['city']),
              isActivity: row['is_activity'] == true,
              isApproved: row['is_approved'] == true,
              startDate: tryParseDateTimeValue(
                row['start_date'],
                toLocal: true,
              ),
              endDate: tryParseDateTimeValue(row['end_date'], toLocal: true),
            );
          }),
        ),
        performance: ModelContentPerformance.fromTotals(
          Map<String, dynamic>.from(json['totals'] as Map),
        ),
      );

  /// Pure projection of owner-scoped, already parsed performance snapshots.
  /// Network access and authentication remain in Service/Controller.
  factory VendorContentMetrics.fromPerformance({
    required ModelContentPerformance events,
    required ModelContentPerformance attractions,
    required DateTime now,
  }) {
    final today = DateTime(now.year, now.month, now.day);
    var published = 0;
    var pending = 0;
    var activeEvents = 0;
    var activeAttractions = 0;
    final submissions = <VendorRecentSubmission>[];
    const previewLimit = 5;
    var requiresFullSort = false;
    VendorRecentSubmission submissionFor(
      ContentPerformanceItem item,
      bool activity,
    ) => VendorRecentSubmission(
      id: item.id,
      name: item.name,
      city: item.city,
      isActivity: activity,
      isApproved: item.approved,
      startDate: item.starts,
      endDate: item.ends,
    );
    int compare(VendorRecentSubmission left, VendorRecentSubmission right) =>
        _compareRecentSubmissions(left, right, today);

    void offer(VendorRecentSubmission candidate) {
      if (submissions.length == previewLimit) {
        final order = compare(candidate, submissions.last);
        if (order > 0) return;
        if (order == 0) requiresFullSort = true;
      }
      var index = 0;
      while (index < submissions.length) {
        final order = compare(candidate, submissions[index]);
        if (order == 0) requiresFullSort = true;
        if (order < 0) break;
        index++;
      }
      if (index >= previewLimit) return;
      submissions.insert(index, candidate);
      if (submissions.length > previewLimit) submissions.removeLast();
    }

    void collect(ModelContentPerformance source, {required bool activity}) {
      for (final item in source.items) {
        item.approved ? published++ : pending++;
        // Preserve the previous policy: only an absent end field falls back
        // to start; an empty/invalid end remains an open-ended record.
        final end = item.source['end_date'] == null ? item.starts : item.ends;
        if (end == null || !end.isBefore(today)) {
          activity ? activeEvents++ : activeAttractions++;
        }
        if (!requiresFullSort) offer(submissionFor(item, activity));
      }
    }

    collect(events, activity: true);
    collect(attractions, activity: false);
    if (requiresFullSort) {
      // List.sort is not stable. Preserve its original input and full-sort tie
      // behavior whenever equal keys could influence the bounded preview.
      submissions
        ..clear()
        ..addAll(events.items.map((item) => submissionFor(item, true)))
        ..addAll(attractions.items.map((item) => submissionFor(item, false)))
        ..sort(compare);
    }
    return VendorContentMetrics(
      published: published,
      pending: pending,
      activeEvents: activeEvents,
      activeAttractions: activeAttractions,
      recentSubmissions: List.unmodifiable(submissions.take(previewLimit)),
      performance: ModelContentPerformance.combine([events, attractions]),
    );
  }
}

int _compareRecentSubmissions(
  VendorRecentSubmission left,
  VendorRecentSubmission right,
  DateTime today,
) {
  if (left.isApproved != right.isApproved) return left.isApproved ? 1 : -1;
  final leftDate = left.startDate ?? left.endDate;
  final rightDate = right.startDate ?? right.endDate;
  if (leftDate == null && rightDate == null) return 0;
  if (leftDate == null) return 1;
  if (rightDate == null) return -1;
  final leftUpcoming = !leftDate.isBefore(today);
  final rightUpcoming = !rightDate.isBefore(today);
  if (leftUpcoming != rightUpcoming) return leftUpcoming ? -1 : 1;
  return leftUpcoming
      ? leftDate.compareTo(rightDate)
      : rightDate.compareTo(leftDate);
}

class VendorRecentSubmission {
  const VendorRecentSubmission({
    required this.id,
    required this.name,
    required this.city,
    required this.isActivity,
    required this.isApproved,
    this.startDate,
    this.endDate,
  });

  final String id;
  final String name;
  final String city;
  final bool isActivity;
  final bool isApproved;
  final DateTime? startDate;
  final DateTime? endDate;
}
