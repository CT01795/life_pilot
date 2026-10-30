import 'package:life_pilot/subscription/subscription_entitlement_quota.dart';
import 'package:life_pilot/subscription/model_quota_free_period.dart';
import 'package:life_pilot/utils/value_parser.dart';

class SubscriptionUsage {
  const SubscriptionUsage({
    required this.resource,
    required this.used,
    required this.quota,
  });

  final String resource;
  final int used;
  final int quota;

  bool get isUnlimited => quota < 0 || quota >= 9000000000000000000;
  bool get isFull => !isUnlimited && used >= quota;

  factory SubscriptionUsage.fromJson(Map<String, dynamic> json) {
    return SubscriptionUsage(
      resource: parseStringValue(json['resource']),
      used: parseIntValue(json['used']),
      quota: parseIntValue(json['quota']),
    );
  }
}

class SubscriptionSnapshot {
  const SubscriptionSnapshot({
    required this.plan,
    required this.usage,
    this.status = 'inactive',
    this.currentPeriodEnd,
    this.cancelAtPeriodEnd = false,
    this.storagePlan = 'cloud',
    this.quotaMultiplier = 1,
    this.quarterlyPricePaidTwd,
    this.pricingVersionName,
    this.pricingEffectiveAt,
    this.lastDataActivityAt,
    this.downgradeGraceEndsAt,
    this.entitlements = const [],
    this.promotionPeriods,
  });

  static const free = SubscriptionSnapshot(plan: 'free', usage: {});

  final String plan;
  final Map<String, SubscriptionUsage> usage;
  final String status;
  final DateTime? currentPeriodEnd;
  final bool cancelAtPeriodEnd;
  final String storagePlan;
  final int quotaMultiplier;
  final int? quarterlyPricePaidTwd;
  final String? pricingVersionName;
  final DateTime? pricingEffectiveAt;
  final DateTime? lastDataActivityAt;
  final DateTime? downgradeGraceEndsAt;
  final List<SubscriptionEntitlement> entitlements;

  /// Null denotes an older RPC; an empty list is an authoritative empty result.
  final List<QuotaFreePeriod>? promotionPeriods;

  bool get isPlus => plan == 'plus';
  bool get configurationMissing => status == 'configuration_missing';
  SubscriptionUsage? operator [](String resource) => usage[resource];

  SubscriptionSnapshot copyWithUsage(Map<String, SubscriptionUsage> newUsage) {
    return SubscriptionSnapshot(
      plan: plan,
      usage: newUsage,
      status: status,
      currentPeriodEnd: currentPeriodEnd,
      cancelAtPeriodEnd: cancelAtPeriodEnd,
      storagePlan: storagePlan,
      quotaMultiplier: quotaMultiplier,
      quarterlyPricePaidTwd: quarterlyPricePaidTwd,
      pricingVersionName: pricingVersionName,
      pricingEffectiveAt: pricingEffectiveAt,
      lastDataActivityAt: lastDataActivityAt,
      downgradeGraceEndsAt: downgradeGraceEndsAt,
      entitlements: entitlements,
      promotionPeriods: promotionPeriods,
    );
  }
}

class SubscriptionEntitlement {
  const SubscriptionEntitlement({
    required this.versionName,
    required this.effectiveAt,
    required this.storagePlan,
    required this.multiplier,
    required this.pricePaidTwd,
    required this.endsAt,
    required this.quotas,
  });

  final String versionName;
  final DateTime effectiveAt;
  final String storagePlan;
  final int multiplier;
  final int pricePaidTwd;
  final DateTime endsAt;
  final Map<String, int> quotas;

  factory SubscriptionEntitlement.fromJson(Map<String, dynamic> json) {
    final rawQuotas = Map<String, dynamic>.from(
      json['entitlement_snapshot'] as Map? ?? const {},
    );
    final multiplier = parseIntValue(json['quota_multiplier'], fallback: 1);
    return SubscriptionEntitlement(
      versionName: parseStringValue(json['version_name']),
      effectiveAt:
          tryParseDateTimeValue(json['effective_at']) ?? DateTime.now(),
      storagePlan: parseStringValue(json['storage_plan'], fallback: 'cloud'),
      multiplier: multiplier,
      pricePaidTwd: parseIntValue(json['quarterly_price_paid_twd']),
      endsAt: tryParseDateTimeValue(json['ends_at']) ?? DateTime.now(),
      quotas: {
        for (final resource in subscriptionQuotaResources)
          resource: ?entitlementSnapshotQuota(
            rawQuotas,
            resource,
            multiplier: multiplier,
          ),
      },
    );
  }
}
