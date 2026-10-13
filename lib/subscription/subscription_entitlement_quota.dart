const subscriptionQuotaResources = <String>[
  'calendar_events',
  'recommended_events',
  'recommended_attractions',
  'accounting_detail',
  'point_record_detail',
  'memory_trace',
  'game_questions',
  'calendar_shares',
  'image_bytes',
  'answer_history_days',
];

/// Reads one immutable entitlement snapshot without applying a multiplier
/// twice. New snapshots use canonical resource keys and already contain the
/// purchased multiplier. Older snapshots use quota-column names, store image
/// capacity in MB, and still need the entitlement multiplier applied.
int? entitlementSnapshotQuota(
  Map<String, dynamic> snapshot,
  String resource, {
  required int multiplier,
}) {
  final canonical = _asInt(snapshot[resource]);
  if (canonical != null) return canonical;

  final legacyKey = switch (resource) {
    'calendar_events' => 'calendar_quota',
    'recommended_events' => 'recommended_event_quota',
    'recommended_attractions' => 'recommended_attraction_quota',
    'accounting_detail' => 'accounting_quota',
    'point_record_detail' => 'point_quota',
    'memory_trace' => 'memory_quota',
    'game_questions' => 'game_question_quota',
    'calendar_shares' => 'calendar_share_quota',
    'image_bytes' => 'image_megabytes',
    'answer_history_days' => 'answer_history_days',
    _ => null,
  };
  if (legacyKey == null) return null;
  final legacy = _asInt(snapshot[legacyKey]);
  if (legacy == null) return null;
  final normalizedMultiplier = multiplier.clamp(1, 1000);
  if (resource == 'answer_history_days') return legacy;
  return resource == 'image_bytes'
      ? legacy * normalizedMultiplier * 1024 * 1024
      : legacy * normalizedMultiplier;
}

int? _asInt(Object? value) {
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '');
}
