import 'package:flutter/material.dart';
import 'package:life_pilot/auth/controller_auth.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/subscription/service_subscription.dart';
import 'package:life_pilot/utils/const.dart';
import 'package:provider/provider.dart';

class PageSubscriptionPlans extends StatefulWidget {
  const PageSubscriptionPlans({super.key});

  @override
  State<PageSubscriptionPlans> createState() => _PageSubscriptionPlansState();
}

class _PageSubscriptionPlansState extends State<PageSubscriptionPlans> {
  late final Future<List<SubscriptionPricingVersion>> _pricingVersions;

  @override
  void initState() {
    super.initState();
    _pricingVersions = ServiceSubscription().fetchPricingVersions();
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final subscription = context.watch<ControllerAuth>().subscription;
    final endDate = subscription.currentPeriodEnd;
    final dates = MaterialLocalizations.of(context);
    String? formatDate(DateTime? value) {
      if (value == null) return null;
      final local = value.toLocal();
      return local.year == DateTime.now().year
          ? dates.formatShortMonthDay(local)
          : dates.formatMediumDate(local);
    }

    final endLabel = formatDate(endDate);
    final pricingEffectiveLabel = formatDate(subscription.pricingEffectiveAt);

    return Scaffold(
      appBar: AppBar(title: Text(loc.subscriptionPlansTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: Icon(
                subscription.isPlus ? Icons.workspace_premium : Icons.person,
              ),
              title: Text(subscription.isPlus
                  ? loc.subscriptionCurrentPlus
                  : loc.subscriptionCurrentFree),
              subtitle: endLabel == null
                  ? Text(loc.subscriptionInactiveAccountWarning)
                  : Text(loc.subscriptionValidUntil(endLabel)),
            ),
          ),
          Gaps.h16,
          if (subscription.usage.isNotEmpty) ...[
            Gaps.h16,
            Text(
              loc.subscriptionActualQuotaTitle,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            Gaps.h8,
            Card(
              child: Column(
                children: subscription.usage.values.map((usage) {
                  final label = _resourceLabel(loc, usage.resource);
                  final used = usage.resource == 'image_bytes'
                      ? '${(usage.used / 1024 / 1024).toStringAsFixed(1)} MB'
                      : usage.used.toString();
                  final quota = usage.resource == 'image_bytes'
                      ? '${(usage.quota / 1024 / 1024).toStringAsFixed(0)} MB'
                      : usage.quota.toString();
                  return ListTile(
                    dense: true,
                    leading: usage.isUnlimited
                        ? const Icon(Icons.all_inclusive)
                        : null,
                    title: Text(label),
                    trailing: Text(
                      usage.isUnlimited ? '$used / ∞' : '$used / $quota',
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
          if (subscription.isPlus) ...[
            Gaps.h16,
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Wrap(
                  spacing: 24,
                  runSpacing: 12,
                  children: [
                    _Fact(
                      label: loc.subscriptionPricingVersion,
                      value: subscription.pricingVersionName ?? '-',
                    ),
                    if (pricingEffectiveLabel != null)
                      _Fact(
                        label: loc.subscriptionEffectiveDate,
                        value: pricingEffectiveLabel,
                      ),
                    _Fact(
                      label: loc.subscriptionQuotaMultiplier,
                      value: '${subscription.quotaMultiplier}×',
                    ),
                    if (subscription.quarterlyPricePaidTwd != null)
                      _Fact(
                        label: loc.subscriptionQuarterlyPayment,
                        value: 'NT\$${subscription.quarterlyPricePaidTwd}',
                      ),
                  ],
                ),
              ),
            ),
            Gaps.h16,
          ],
          if (subscription.entitlements.isNotEmpty) ...[
            ...subscription.entitlements.map(
              (entitlement) => Card(
                child: ExpansionTile(
                  leading: const Icon(Icons.confirmation_number_outlined),
                  title: Text(loc.subscriptionVersionOffer(
                    entitlement.versionName,
                    formatDate(entitlement.effectiveAt)!,
                    entitlement.pricePaidTwd,
                  )),
                  subtitle: Text(
                    '${entitlement.multiplier}× · '
                    '${loc.subscriptionValidUntil(formatDate(entitlement.endsAt)!)}',
                  ),
                  childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  children: entitlement.quotas.entries
                      .where((entry) => entry.key != 'answer_history_days')
                      .map((entry) {
                    final value = entry.key == 'image_bytes'
                        ? '${entry.value ~/ 1024 ~/ 1024} MB'
                        : entry.value.toString();
                    return Row(
                      children: [
                        Expanded(child: Text(_resourceLabel(loc, entry.key))),
                        Text(value),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
            Gaps.h8,
          ],
          FutureBuilder<List<SubscriptionPricingVersion>>(
            future: _pricingVersions,
            builder: (context, snapshot) {
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const SizedBox.shrink();
              }
              final latest = snapshot.data!.first;
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _PricingVersionCard(
                  version: latest,
                  effectiveDate: formatDate(latest.effectiveAt)!,
                ),
              );
            },
          ),
          LayoutBuilder(
            builder: (context, constraints) {
              final freeCard = _PlanCard(
                title: loc.subscriptionFreeName,
                price: loc.subscriptionFreePrice,
                features: [
                  loc.subscriptionFreePersonalRecords,
                  loc.subscriptionFreeGameQuestions,
                  loc.subscriptionFreeSharing,
                  loc.subscriptionFreeImages,
                  loc.subscriptionFreeAnswerHistory,
                ],
                selected: !subscription.isPlus,
              );
              final cloudPlusCard = _PlanCard(
                title: loc.subscriptionPlusName,
                price: loc.subscriptionPlusPrice,
                features: [
                  loc.subscriptionPlusPersonalRecords,
                  loc.subscriptionPlusGameQuestions,
                  loc.subscriptionPlusSharing,
                  loc.subscriptionPlusImages,
                  loc.subscriptionPlusAnswerHistory,
                ],
                selected:
                    subscription.isPlus && subscription.storagePlan == 'cloud',
                highlighted: true,
              );
              final localPlusCard = _PlanCard(
                title: loc.subscriptionLocalPaidName,
                price: loc.subscriptionLocalPaidPrice,
                features: [
                  loc.subscriptionLocalPaidFeature,
                  loc.subscriptionLocalAnswerHistory,
                ],
                selected:
                    subscription.isPlus && subscription.storagePlan == 'local',
              );
              final currentCard = subscription.isPlus
                  ? (subscription.storagePlan == 'local'
                      ? localPlusCard
                      : cloudPlusCard)
                  : freeCard;
              final cards = subscription.isPlus
                  ? <Widget>[
                      currentCard,
                      freeCard,
                      if (!identical(currentCard, cloudPlusCard)) cloudPlusCard,
                      if (!identical(currentCard, localPlusCard)) localPlusCard,
                    ]
                  : <Widget>[freeCard, cloudPlusCard, localPlusCard];
              if (constraints.maxWidth >= 900) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: cards[0]),
                    Gaps.w16,
                    Expanded(child: cards[1]),
                    Gaps.w16,
                    Expanded(child: cards[2]),
                  ],
                );
              }
              return Column(
                children: [
                  cards[0],
                  Gaps.h12,
                  cards[1],
                  Gaps.h12,
                  cards[2],
                ],
              );
            },
          ),
          Gaps.h16,
          FilledButton.icon(
            onPressed: null,
            icon: const Icon(Icons.shopping_bag_outlined),
            label: Text(loc.subscriptionPurchaseComingSoon),
          ),
          Gaps.h8,
          Text(
            loc.subscriptionPurchaseExplanation,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

String _resourceLabel(AppLocalizations loc, String resource) =>
    switch (resource) {
      'calendar_events' => loc.personalEvent,
      'accounting_detail' => loc.accountRecords,
      'point_record_detail' => loc.pointsRecord,
      'memory_trace' => loc.memoryTrace,
      'game_questions' => loc.game,
      'calendar_shares' => loc.calendarSharing,
      'image_bytes' => loc.subscriptionImageStorage,
      _ => resource,
    };

class _PricingVersionCard extends StatelessWidget {
  const _PricingVersionCard({
    required this.version,
    required this.effectiveDate,
  });

  final SubscriptionPricingVersion version;
  final String effectiveDate;

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(loc.subscriptionNextVersionTitle,
                style: Theme.of(context).textTheme.titleLarge),
            Gaps.h4,
            Text(loc.subscriptionVersionOffer(
              version.name,
              effectiveDate,
              version.quarterlyPriceTwd,
            )),
            const Divider(height: 24),
            ...version.quotas.entries
                .where((entry) => entry.key != 'answer_history_days')
                .map((entry) {
              final value = entry.key == 'image_bytes'
                  ? '${entry.value ~/ 1024 ~/ 1024} MB'
                  : entry.value.toString();
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Expanded(child: Text(_resourceLabel(loc, entry.key))),
                    Text(value),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 150,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.labelMedium),
            Gaps.h4,
            Text(value, style: Theme.of(context).textTheme.titleMedium),
          ],
        ),
      );
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.title,
    required this.price,
    required this.features,
    required this.selected,
    this.highlighted = false,
  });

  final String title;
  final String price;
  final List<String> features;
  final bool selected;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      color: highlighted ? colors.primaryContainer : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: selected
            ? BorderSide(color: colors.primary, width: 2)
            : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(title,
                      style: Theme.of(context).textTheme.titleLarge),
                ),
                if (selected) Icon(Icons.check_circle, color: colors.primary),
              ],
            ),
            Gaps.h4,
            Text(price, style: Theme.of(context).textTheme.headlineSmall),
            Gaps.h12,
            ...features.map(
              (feature) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.check, size: 20),
                    Gaps.w8,
                    Expanded(child: Text(feature)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
