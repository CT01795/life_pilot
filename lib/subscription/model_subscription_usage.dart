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
      resource: json['resource']?.toString() ?? '',
      used: (json['used'] as num?)?.toInt() ?? 0,
      quota: (json['quota'] as num?)?.toInt() ?? 0,
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
    this.entitlements = const [],
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
  final List<SubscriptionEntitlement> entitlements;

  bool get isPlus => plan == 'plus';
  SubscriptionUsage? operator [](String resource) => usage[resource];

  SubscriptionSnapshot copyWithUsage(
    Map<String, SubscriptionUsage> newUsage,
  ) {
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
      entitlements: entitlements,
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
    return SubscriptionEntitlement(
      versionName: json['version_name']?.toString() ?? '',
      effectiveAt: DateTime.parse(json['effective_at'].toString()),
      storagePlan: json['storage_plan']?.toString() ?? 'cloud',
      multiplier: (json['quota_multiplier'] as num?)?.toInt() ?? 1,
      pricePaidTwd: (json['quarterly_price_paid_twd'] as num?)?.toInt() ?? 0,
      endsAt: DateTime.parse(json['ends_at'].toString()),
      quotas: rawQuotas.map(
        (key, value) => MapEntry(key, (value as num?)?.toInt() ?? 0),
      ),
    );
  }
}
