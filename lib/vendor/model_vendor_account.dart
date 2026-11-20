import 'package:life_pilot/utils/value_parser.dart';
import 'package:life_pilot/event/model_content_performance.dart';
import 'package:life_pilot/subscription/model_billing_cycle.dart';

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
    this.billingCycle = BillingCycle.month,
  });

  final String id;
  final String code;
  final String versionName;
  final DateTime effectiveAt;
  final int quarterlyPriceTwd;
  int get priceTwd => quarterlyPriceTwd;
  final BillingCycle billingCycle;
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
        billingCycle: BillingCycle.from(json['billing_cycle']),
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

  VendorSubscriptionStatus copyWith({
    int? eventUsed,
    int? attractionUsed,
    int? imageBytesUsed,
  }) => VendorSubscriptionStatus(
    plan: plan,
    status: status,
    eventUsed: eventUsed ?? this.eventUsed,
    attractionUsed: attractionUsed ?? this.attractionUsed,
    imageBytesUsed: imageBytesUsed ?? this.imageBytesUsed,
    currentPeriodEnd: currentPeriodEnd,
  );
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
          (json['recent_submissions'] as List)
              .take(5)
              .map(VendorRecentSubmission.fromJson),
        ),
        performance: ModelContentPerformance.fromTotals(
          Map<String, dynamic>.from(json['totals'] as Map),
        ),
      );

  VendorContentMetrics copyWith({
    int? published,
    int? pending,
    int? activeEvents,
    int? activeAttractions,
    Iterable<VendorRecentSubmission>? recentSubmissions,
  }) => VendorContentMetrics(
    published: published ?? this.published,
    pending: pending ?? this.pending,
    activeEvents: activeEvents ?? this.activeEvents,
    activeAttractions: activeAttractions ?? this.activeAttractions,
    recentSubmissions: List.unmodifiable(
      recentSubmissions ?? this.recentSubmissions,
    ),
    performance: performance,
  );
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

  factory VendorRecentSubmission.fromJson(Object? value) {
    final row = Map<String, dynamic>.from(value as Map);
    return VendorRecentSubmission(
      id: parseStringValue(row['id']),
      name: parseStringValue(row['name']),
      city: parseStringValue(row['city']),
      isActivity: row['is_activity'] == true,
      isApproved: row['is_approved'] == true,
      startDate: tryParseDateTimeValue(row['start_date'], toLocal: true),
      endDate: tryParseDateTimeValue(row['end_date'], toLocal: true),
    );
  }
}
