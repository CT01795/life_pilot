import 'package:life_pilot/subscription/subscription_constants.dart';
import 'package:life_pilot/utils/value_parser.dart';

const subscriptionQuotaResources = SubscriptionResource.quotaResources;

/// Reads one immutable entitlement snapshot without applying a multiplier
/// twice. New snapshots use canonical resource keys and already contain the
/// purchased multiplier. Older snapshots use quota-column names, store image
/// capacity in MB, and still need the entitlement multiplier applied.
int? entitlementSnapshotQuota(
  Map<String, dynamic> snapshot,
  String resource, {
  required int multiplier,
}) {
  final canonical = tryParseIntValue(snapshot[resource]);
  if (canonical != null) return canonical;

  final legacyKey = switch (resource) {
    SubscriptionResource.calendarEvents => 'calendar_quota',
    SubscriptionResource.recommendedEvents => 'recommended_event_quota',
    SubscriptionResource.recommendedAttractions =>
      'recommended_attraction_quota',
    SubscriptionResource.accountingDetail => 'accounting_quota',
    SubscriptionResource.pointRecordDetail => 'point_quota',
    SubscriptionResource.memoryTrace => 'memory_quota',
    SubscriptionResource.gameQuestions => 'game_question_quota',
    SubscriptionResource.calendarShares => 'calendar_share_quota',
    SubscriptionResource.imageBytes => 'image_megabytes',
    SubscriptionResource.answerHistoryDays => 'answer_history_days',
    _ => null,
  };
  if (legacyKey == null) return null;
  final legacy = tryParseIntValue(snapshot[legacyKey]);
  if (legacy == null) return null;
  final normalizedMultiplier = multiplier.clamp(1, 1000);
  if (resource == SubscriptionResource.answerHistoryDays) return legacy;
  return resource == SubscriptionResource.imageBytes
      ? legacy * normalizedMultiplier * 1024 * 1024
      : legacy * normalizedMultiplier;
}
