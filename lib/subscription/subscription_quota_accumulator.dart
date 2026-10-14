/// Adds an already-resolved quota without applying pricing multipliers again.
void addSubscriptionQuota(Map<String, int> totals, String resource, int value) {
  totals.update(resource, (current) => current + value, ifAbsent: () => value);
}

/// Merges resolved entitlement quotas into an owned accumulator.
void addSubscriptionQuotas(Map<String, int> totals, Map<String, int> quotas) {
  for (final entry in quotas.entries) {
    addSubscriptionQuota(totals, entry.key, entry.value);
  }
}
