import 'package:life_pilot/subscription/subscription_constants.dart';
import 'package:life_pilot/utils/value_parser.dart';

const subscriptionQuotaResources = SubscriptionResource.quotaResources;

/// Reads one immutable entitlement snapshot without applying a multiplier
/// twice. New snapshots use canonical resource keys and already contain the
/// purchased multiplier. Older snapshots use quota-column names, store image
/// capacity in MB, and still need the entitlement multiplier applied.
int? entitlementSnapshotQuota(Map<String, dynamic> snapshot, String resource) =>
    tryParseIntValue(snapshot[resource]);
