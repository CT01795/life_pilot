class SubscriptionUsage {
  const SubscriptionUsage({
    required this.resource,
    required this.used,
    required this.quota,
  });

  final String resource;
  final int used;
  final int quota;

  bool get isFull => used >= quota;

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
  });

  static const free = SubscriptionSnapshot(plan: 'free', usage: {});

  final String plan;
  final Map<String, SubscriptionUsage> usage;
  final String status;
  final DateTime? currentPeriodEnd;
  final bool cancelAtPeriodEnd;

  bool get isPlus => plan == 'plus';
  SubscriptionUsage? operator [](String resource) => usage[resource];
}
