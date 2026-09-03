import 'package:flutter/material.dart';
import 'package:life_pilot/auth/controller_auth.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/subscription/service_subscription.dart';
import 'package:provider/provider.dart';

class SubscriptionUsageBanner extends StatelessWidget {
  const SubscriptionUsageBanner({
    super.key,
    required this.resource,
  });

  final String resource;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<ControllerAuth>();
    final usage = auth.subscription[resource];
    if (auth.isSysAdmin || usage == null) return const SizedBox.shrink();
    final loc = AppLocalizations.of(context)!;
    final full = usage.isFull;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Semantics(
        liveRegion: full,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: full
                ? Theme.of(context).colorScheme.errorContainer
                : Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(full ? Icons.warning_amber_rounded : Icons.data_usage,
                  size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  usage.isUnlimited
                      ? loc.subscriptionLocalUsage(usage.used)
                      : loc.subscriptionUsage(usage.used, usage.quota),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String subscriptionErrorMessage(AppLocalizations loc, Object error) {
  final text = error.toString();
  if (text.contains('LIFE_PILOT_PLUS_REQUIRED:images')) {
    return loc.subscriptionImagePlusOnly;
  }
  if (text.contains('LIFE_PILOT_RENEWAL_REQUIRED')) {
    return loc.subscriptionRenewalRequired;
  }
  final limit = SubscriptionLimitException.tryParse(error);
  if (limit != null && !limit.plusRequired) {
    if (limit.used != null && limit.quota != null) {
      return loc.subscriptionQuotaReachedDetail(
        limit.used!,
        limit.quota!,
        (limit.quota! - limit.used!).clamp(0, limit.quota!),
      );
    }
    return loc.subscriptionQuotaReached;
  }
  return '';
}
