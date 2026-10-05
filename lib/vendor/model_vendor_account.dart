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
        id: json['id']?.toString() ?? json['plan_code']?.toString() ?? '',
        code: json['plan_code']?.toString() ?? 'free',
        versionName: json['version_name']?.toString() ?? '',
        effectiveAt:
            DateTime.tryParse(json['effective_at']?.toString() ?? '') ??
            DateTime.now(),
        quarterlyPriceTwd: (json['quarterly_price_twd'] as num?)?.toInt() ?? 0,
        eventQuota: (json['event_quota'] as num?)?.toInt() ?? 0,
        attractionQuota: (json['attraction_quota'] as num?)?.toInt() ?? 0,
        imageMegabytes: (json['image_megabytes'] as num?)?.toInt() ?? 0,
        analyticsDays: (json['analytics_days'] as num?)?.toInt() ?? 0,
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
      status: json['status']?.toString() ?? 'active',
      eventUsed: (json['event_used'] as num?)?.toInt() ?? 0,
      attractionUsed: (json['attraction_used'] as num?)?.toInt() ?? 0,
      imageBytesUsed: (json['image_bytes_used'] as num?)?.toInt() ?? 0,
      currentPeriodEnd: DateTime.tryParse(
        json['current_period_end']?.toString() ?? '',
      ),
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
  });

  final int published;
  final int pending;
  final int activeEvents;
  final int activeAttractions;
  final List<VendorRecentSubmission> recentSubmissions;
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

class VendorEngagementMetrics {
  const VendorEngagementMetrics({
    required this.analyticsDays,
    required this.pageViews,
    required this.cardClicks,
    required this.registrationClicks,
    required this.saves,
    required this.likes,
    required this.dislikes,
  });

  const VendorEngagementMetrics.empty({this.analyticsDays = 30})
    : pageViews = 0,
      cardClicks = 0,
      registrationClicks = 0,
      saves = 0,
      likes = 0,
      dislikes = 0;

  final int analyticsDays;
  final int pageViews;
  final int cardClicks;
  final int registrationClicks;
  final int saves;
  final int likes;
  final int dislikes;

  factory VendorEngagementMetrics.fromJson(Map<String, dynamic> json) {
    int value(String key) => (json[key] as num?)?.toInt() ?? 0;
    return VendorEngagementMetrics(
      analyticsDays: value('analytics_days'),
      pageViews: value('page_views'),
      cardClicks: value('card_clicks'),
      registrationClicks: value('registration_clicks'),
      saves: value('saves'),
      likes: value('likes'),
      dislikes: value('dislikes'),
    );
  }
}
