import 'package:flutter/material.dart';
import 'package:life_pilot/apps/controller_page_main.dart';
import 'package:life_pilot/auth/controller_auth.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/local_storage/local_data_store.dart';
import 'package:life_pilot/subscription/model_subscription_usage.dart';
import 'package:life_pilot/subscription/service_subscription.dart';
import 'package:life_pilot/subscription/subscription_constants.dart';
import 'package:life_pilot/subscription/subscription_entitlement_utils.dart';
import 'package:life_pilot/subscription/subscription_expiry_schedule.dart';
import 'package:life_pilot/subscription/subscription_quota_presentation.dart';
import 'package:life_pilot/subscription/widgets_admin_pricing_editor.dart';
import 'package:life_pilot/subscription/widgets_admin_subscription_editor.dart';
import 'package:life_pilot/subscription/widgets_admin_quota_free_period.dart';
import 'package:life_pilot/subscription/widgets_subscription_cleanup.dart';
import 'package:life_pilot/utils/const.dart';
import 'package:life_pilot/utils/widgets/widgets_adaptive_button.dart';
import 'package:life_pilot/utils/enum.dart';
import 'package:provider/provider.dart';
import 'package:life_pilot/vendor/widgets_admin_vendor_pricing.dart';

class PageSubscriptionPlans extends StatefulWidget {
  const PageSubscriptionPlans({super.key});

  @override
  State<PageSubscriptionPlans> createState() => _PageSubscriptionPlansState();
}

class _PageSubscriptionPlansState extends State<PageSubscriptionPlans> {
  late Future<List<SubscriptionPricingVersion>> _pricingVersions;
  List<SubscriptionPricingVersion> _availableVersions = const [];
  SubscriptionPricingVersion? _latestFreeCloudVersion;
  SubscriptionPricingVersion? _latestCloudVersion;
  SubscriptionPricingVersion? _latestLocalVersion;
  int _adminSubscriptionEditorRevision = 0;

  @override
  void initState() {
    super.initState();
    _reloadPricingVersions();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<ControllerAuth>().refreshSubscriptionUsage();
      }
    });
  }

  void _reloadPricingVersions() {
    final future = ServiceSubscription().fetchPricingVersions();
    _pricingVersions = future;
    future.then((versions) {
      if (!mounted) return;
      setState(() {
        _availableVersions = versions;
        _latestFreeCloudVersion = versions
            .where(
              (version) =>
                  version.storagePlan == SubscriptionStoragePlan.cloud &&
                  version.quarterlyPriceTwd == 0,
            )
            .firstOrNull;
        _latestCloudVersion = versions
            .where(
              (version) =>
                  version.storagePlan == SubscriptionStoragePlan.cloud &&
                  version.quarterlyPriceTwd > 0,
            )
            .firstOrNull;
        _latestLocalVersion = versions
            .where(
              (version) => version.storagePlan == SubscriptionStoragePlan.local,
            )
            .firstOrNull;
        _adminSubscriptionEditorRevision++;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final auth = context.watch<ControllerAuth>();
    final canUsePoints = context.select<ControllerPageMain, bool>(
      (controller) => controller.canAccess(PageType.pointsRecord),
    );
    final canUseGame = context.select<ControllerPageMain, bool>(
      (controller) => controller.canAccess(PageType.game),
    );
    bool showResource(String resource) => shouldShowSubscriptionResource(
      resource,
      canUsePoints: canUsePoints,
      canUseGame: canUseGame,
    );
    final subscription = auth.subscription;
    final localStorageSelected =
        auth.preferredStorage == DataStorageLocation.local;
    final currentPricingVersion = localStorageSelected
        ? auth.canUseLocalStorage &&
                  subscription.isPlus &&
                  subscription.storagePlan == SubscriptionStoragePlan.local
              ? _availableVersions
                        .where(
                          (version) =>
                              version.storagePlan ==
                                  SubscriptionStoragePlan.local &&
                              version.name == subscription.pricingVersionName,
                        )
                        .firstOrNull ??
                    _latestLocalVersion
              : null
        : subscription.isPlus
        ? _availableVersions
              .where(
                (version) =>
                    version.storagePlan == subscription.storagePlan &&
                    version.name == subscription.pricingVersionName,
              )
              .firstOrNull
        : _latestFreeCloudVersion;
    final displayedUsage = Map<String, SubscriptionUsage>.from(
      subscription.usage,
    );
    if (currentPricingVersion != null) {
      for (final entry in currentPricingVersion.quotas.entries) {
        if (entry.key == SubscriptionResource.answerHistoryDays) continue;
        if (currentPricingVersion.storagePlan ==
                SubscriptionStoragePlan.local &&
            (entry.key == SubscriptionResource.recommendedEvents ||
                entry.key == SubscriptionResource.recommendedAttractions)) {
          continue;
        }
        final current = displayedUsage[entry.key];
        displayedUsage[entry.key] = SubscriptionUsage(
          resource: entry.key,
          used: current?.used ?? 0,
          quota: auth.isSysAdmin
              ? -1
              : current?.quota ??
                    ((currentPricingVersion.storagePlan ==
                                SubscriptionStoragePlan.local &&
                            entry.value == 0)
                        ? -1
                        : entry.value *
                              (subscription.isPlus
                                  ? subscription.quotaMultiplier
                                  : 1)),
        );
      }
    }
    final currentStoragePlan = auth.preferredStorage.name;
    final now = DateTime.now();
    final currentEntitlements = activeSubscriptionEntitlements(
      subscription.entitlements,
      storagePlan: currentStoragePlan,
      now: now,
    );
    final fallbackQuotas = currentStoragePlan == SubscriptionStoragePlan.cloud
        ? _latestFreeCloudVersion?.quotas ?? const <String, int>{}
        : {for (final resource in displayedUsage.keys) resource: 0};
    final quotaExpiryStages = buildSubscriptionQuotaExpiryStages(
      currentEntitlements,
      fallbackQuotas: fallbackQuotas,
    ).take(2).toList(growable: false);
    final endDate =
        latestEntitlementEnd(currentEntitlements) ??
        subscription.currentPeriodEnd;
    final expiryReminder = buildSubscriptionExpiryReminder(
      currentEntitlements,
      now: now,
      fallbackQuotas: fallbackQuotas,
    );
    final dates = MaterialLocalizations.of(context);
    String? formatDate(DateTime? value) =>
        formatSubscriptionDate(dates, value, now: now);

    final endLabel = formatDate(endDate);
    final graceLabel = formatDate(subscription.downgradeGraceEndsAt);
    final fallbackExpiryDays = endDate == null
        ? null
        : (endDate.toLocal().difference(now).inHours / 24).ceil();
    final overages = displayedUsage.values
        .where((usage) => !usage.isUnlimited && usage.used > usage.quota)
        .toList(growable: false);

    return Scaffold(
      appBar: AppBar(title: Text(loc.subscriptionPlansTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: Icon(
                auth.isSysAdmin
                    ? Icons.admin_panel_settings_outlined
                    : subscription.isPlus
                    ? Icons.workspace_premium
                    : Icons.person,
              ),
              title: Text(
                auth.isSysAdmin
                    ? loc.subscriptionCurrentAdmin
                    : localStorageSelected
                    ? (auth.canUseLocalStorage &&
                              subscription.isPlus &&
                              subscription.storagePlan ==
                                  SubscriptionStoragePlan.local
                          ? loc.subscriptionCurrentLocalPlus
                          : auth.quotaFreePeriodActive
                          ? loc.subscriptionCurrentLocalPromotion
                          : loc.subscriptionCurrentLocalInactive)
                    : subscription.isPlus
                    ? (subscription.storagePlan == SubscriptionStoragePlan.local
                          ? loc.subscriptionCurrentLocalPlus
                          : loc.subscriptionCurrentCloudPlus)
                    : loc.subscriptionCurrentFree,
              ),
              subtitle:
                  localStorageSelected &&
                      !auth.canUseLocalStorage &&
                      !auth.isSysAdmin
                  ? Text(loc.localSubscriptionRequiredForChanges)
                  : endLabel != null
                  ? Text(loc.subscriptionValidUntil(endLabel))
                  : subscription.isPlus
                  ? null
                  : Text(loc.subscriptionInactiveAccountWarning),
            ),
          ),
          if (!auth.isSysAdmin &&
              subscription.isPlus &&
              ((expiryReminder?.kind == SubscriptionExpiryReminderKind.all) ||
                  (expiryReminder == null &&
                      currentEntitlements.isEmpty &&
                      fallbackExpiryDays != null &&
                      fallbackExpiryDays >= 0 &&
                      fallbackExpiryDays <= 15))) ...[
            Gaps.h12,
            Card(
              color: Theme.of(context).colorScheme.tertiaryContainer,
              child: ListTile(
                leading: const Icon(Icons.notification_important_outlined),
                title: Text(
                  loc.subscriptionExpiringSoon(
                    expiryReminder?.days ?? fallbackExpiryDays!,
                  ),
                ),
                subtitle: Text(
                  localStorageSelected
                      ? loc.subscriptionExpiringLocalImpact
                      : loc.subscriptionExpiringCloudImpact,
                ),
              ),
            ),
          ],
          if (!auth.isSysAdmin &&
              subscription.isPlus &&
              expiryReminder?.kind ==
                  SubscriptionExpiryReminderKind.partial) ...[
            Gaps.h12,
            Card(
              color: Theme.of(context).colorScheme.secondaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      loc.subscriptionPartialExpiringSoon(expiryReminder!.days),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Gaps.h4,
                    Text(loc.subscriptionPartialExpiryImpact),
                    Gaps.h8,
                    for (final entry
                        in expiryReminder.stage.remainingQuotas.entries.where(
                          (entry) =>
                              entry.key != 'answer_history_days' &&
                              showResource(entry.key),
                        ))
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                subscriptionResourceLabel(loc, entry.key),
                              ),
                            ),
                            Text(
                              subscriptionQuotaValue(
                                loc,
                                entry.key,
                                entry.value,
                                zeroMeansNotLimited:
                                    currentStoragePlan == 'local' &&
                                    expiryReminder
                                        .stage
                                        .hasRemainingPaidSubscription,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
          if (graceLabel != null && overages.isNotEmpty) ...[
            Gaps.h12,
            Card(
              color: Theme.of(context).colorScheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      loc.subscriptionDowngradeWarning(graceLabel),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Gaps.h8,
                    for (final usage in overages)
                      Text(
                        loc.subscriptionOverageItem(
                          subscriptionResourceLabel(loc, usage.resource),
                          usage.used,
                          usage.quota,
                          usage.used - usage.quota,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Gaps.h12,
            const SubscriptionDataCleanup(),
          ],
          Gaps.h16,
          if (displayedUsage.isNotEmpty) ...[
            Gaps.h16,
            Text(
              loc.subscriptionActualQuotaTitle,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            Gaps.h8,
            Card(
              child: Column(
                children: displayedUsage.values
                    .where((usage) => showResource(usage.resource))
                    .map((usage) {
                      final label = subscriptionResourceLabel(
                        loc,
                        usage.resource,
                      );
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
                          usage.isUnlimited
                              ? '$used / ${loc.quotaNotLimited}'
                              : '$used / $quota',
                        ),
                      );
                    })
                    .toList(),
              ),
            ),
          ],
          if (quotaExpiryStages.isNotEmpty) ...[
            Gaps.h16,
            Text(
              loc.subscriptionQuotaScheduleTitle,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            Gaps.h8,
            ...quotaExpiryStages.map(
              (stage) => Card(
                child: ExpansionTile(
                  leading: const Icon(Icons.event_busy_outlined),
                  title: Text(
                    loc.subscriptionQuotaAfterExpiry(
                      formatDate(stage.expiresAt)!,
                    ),
                  ),
                  childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  children: stage.remainingQuotas.entries
                      .where(
                        (entry) =>
                            entry.key != 'answer_history_days' &&
                            showResource(entry.key),
                      )
                      .map((entry) {
                        final value = subscriptionQuotaValue(
                          loc,
                          entry.key,
                          entry.value,
                          zeroMeansNotLimited:
                              currentStoragePlan == 'local' &&
                              stage.hasRemainingPaidSubscription,
                        );
                        return Row(
                          children: [
                            Expanded(
                              child: Text(
                                subscriptionResourceLabel(loc, entry.key),
                              ),
                            ),
                            Text(value),
                          ],
                        );
                      })
                      .toList(),
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
              final latestCloud = snapshot.data!
                  .where(
                    (version) =>
                        version.storagePlan == SubscriptionStoragePlan.cloud &&
                        version.quarterlyPriceTwd > 0,
                  )
                  .firstOrNull;
              final latestLocal = snapshot.data!
                  .where(
                    (version) =>
                        version.storagePlan == SubscriptionStoragePlan.local,
                  )
                  .firstOrNull;
              final latestFreeCloud = snapshot.data!
                  .where(
                    (version) =>
                        version.storagePlan == SubscriptionStoragePlan.cloud &&
                        version.quarterlyPriceTwd == 0,
                  )
                  .firstOrNull;
              final cloudCard = latestCloud == null
                  ? null
                  : Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: _PricingVersionCard(
                        version: latestCloud,
                        effectiveDate: formatDate(latestCloud.effectiveAt)!,
                        canUsePoints: canUsePoints,
                        canUseGame: canUseGame,
                      ),
                    );
              final localCard = latestLocal == null
                  ? null
                  : Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: _PricingVersionCard(
                        version: latestLocal,
                        effectiveDate: formatDate(latestLocal.effectiveAt)!,
                        canUsePoints: canUsePoints,
                        canUseGame: canUseGame,
                        publicSubmissionVersion: latestFreeCloud,
                      ),
                    );
              return Column(
                children: (currentStoragePlan == 'local'
                    ? [?localCard, ?cloudCard]
                    : [?cloudCard, ?localCard]),
              );
            },
          ),
          LayoutBuilder(
            builder: (context, constraints) {
              final freeCard = _latestFreeCloudVersion == null
                  ? null
                  : _PlanCard(
                      title: loc.subscriptionFreeName,
                      price:
                          'NT\$${_latestFreeCloudVersion!.quarterlyPriceTwd}',
                      features: _versionFeatures(
                        loc,
                        _latestFreeCloudVersion!,
                        canUsePoints: canUsePoints,
                        canUseGame: canUseGame,
                      ),
                      selected: !auth.isSysAdmin && !subscription.isPlus,
                    );
              final cloudPlusCard = _latestCloudVersion == null
                  ? null
                  : _PlanCard(
                      title: loc.subscriptionCloudVersionName(
                        _latestCloudVersion!.name,
                      ),
                      price: 'NT\$${_latestCloudVersion!.quarterlyPriceTwd}',
                      features: _versionFeatures(
                        loc,
                        _latestCloudVersion!,
                        canUsePoints: canUsePoints,
                        canUseGame: canUseGame,
                      ),
                      selected:
                          !auth.isSysAdmin &&
                          subscription.isPlus &&
                          subscription.storagePlan ==
                              SubscriptionStoragePlan.cloud,
                      highlighted: true,
                    );
              final localPlusCard = _latestLocalVersion == null
                  ? null
                  : _PlanCard(
                      title: loc.subscriptionLocalVersionName(
                        _latestLocalVersion!.name,
                      ),
                      price: 'NT\$${_latestLocalVersion!.quarterlyPriceTwd}',
                      features: [
                        loc.subscriptionLocalRequiresActiveSubscription,
                        loc.subscriptionLocalPaidFeature,
                        if (canUseGame) loc.subscriptionLocalAnswerHistory,
                        if (_latestFreeCloudVersion case final freeVersion?)
                          loc.subscriptionLocalPublicSubmissionQuota(
                            freeVersion.quotas['recommended_events'] ?? 0,
                            freeVersion.quotas['recommended_attractions'] ?? 0,
                          ),
                      ],
                      selected:
                          !auth.isSysAdmin &&
                          subscription.isPlus &&
                          subscription.storagePlan ==
                              SubscriptionStoragePlan.local,
                    );
              final currentCard = subscription.isPlus
                  ? (subscription.storagePlan == SubscriptionStoragePlan.local
                        ? localPlusCard
                        : cloudPlusCard)
                  : freeCard;
              final remainingCards =
                  <Widget?>[freeCard, cloudPlusCard, localPlusCard]
                      .whereType<Widget>()
                      .where((card) => !identical(card, currentCard));
              final cards = <Widget>[?currentCard, ...remainingCards];
              if (cards.isEmpty) return const SizedBox.shrink();
              if (constraints.maxWidth >= 900) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var i = 0; i < cards.length; i++) ...[
                      if (i > 0) Gaps.w16,
                      Expanded(child: cards[i]),
                    ],
                  ],
                );
              }
              return Column(
                children: [
                  for (var i = 0; i < cards.length; i++) ...[
                    if (i > 0) Gaps.h12,
                    cards[i],
                  ],
                ],
              );
            },
          ),
          Gaps.h16,
          FilledButton.icon(
            onPressed: null,
            icon: const Icon(Icons.shopping_bag_outlined),
            label: AdaptiveButtonLabel(loc.subscriptionPurchaseComingSoon),
          ),
          Gaps.h8,
          Text(
            loc.subscriptionPurchaseExplanation,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (auth.isSysAdmin) ...[
            Gaps.h24,
            const Divider(),
            Gaps.h8,
            const AdminQuotaFreePeriod(),
            Gaps.h16,
            AdminPricingVersionEditor(onSaved: _reloadPricingVersions),
            Gaps.h16,
            AdminSubscriptionEditor(
              key: ValueKey(_adminSubscriptionEditorRevision),
              onSaved: () => auth.refreshSubscriptionUsage(),
            ),
            Gaps.h16,
            const AdminVendorPricing(),
          ],
        ],
      ),
    );
  }
}

List<String> _versionFeatures(
  AppLocalizations loc,
  SubscriptionPricingVersion version, {
  required bool canUsePoints,
  required bool canUseGame,
}) {
  if (version.storagePlan == SubscriptionStoragePlan.local) {
    return [
      loc.subscriptionLocalRequiresActiveSubscription,
      loc.subscriptionLocalPaidFeature,
      if (canUseGame) loc.subscriptionLocalAnswerHistory,
    ];
  }
  return [
    for (final entry in version.quotas.entries)
      if (entry.key != SubscriptionResource.answerHistoryDays &&
          shouldShowSubscriptionResource(
            entry.key,
            canUsePoints: canUsePoints,
            canUseGame: canUseGame,
          ))
        '${subscriptionResourceLabel(loc, entry.key)}：${subscriptionQuotaValue(loc, entry.key, entry.value)}',
    if (canUseGame)
      '${loc.adminPricingAnswerDays}：${version.quotas['answer_history_days'] ?? 0}',
  ];
}

class _PricingVersionCard extends StatelessWidget {
  const _PricingVersionCard({
    required this.version,
    required this.effectiveDate,
    required this.canUsePoints,
    required this.canUseGame,
    this.publicSubmissionVersion,
  });

  final SubscriptionPricingVersion version;
  final String effectiveDate;
  final bool canUsePoints;
  final bool canUseGame;
  final SubscriptionPricingVersion? publicSubmissionVersion;

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              version.storagePlan == SubscriptionStoragePlan.local
                  ? loc.subscriptionNextLocalVersionName(version.name)
                  : loc.subscriptionNextCloudVersionName(version.name),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            Gaps.h4,
            Text(
              loc.subscriptionVersionOffer(
                version.name,
                effectiveDate,
                version.quarterlyPriceTwd,
              ),
            ),
            const Divider(height: 24),
            if (version.storagePlan == SubscriptionStoragePlan.local) ...[
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.verified_user_outlined),
                title: Text(loc.subscriptionLocalRequiresActiveSubscription),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.all_inclusive),
                title: Text(loc.subscriptionLocalPaidFeature),
              ),
              if (canUseGame)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.history_outlined),
                  title: Text(loc.subscriptionLocalAnswerHistory),
                ),
              if (publicSubmissionVersion case final freeVersion?) ...[
                const Divider(),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.public_outlined),
                  title: Text(loc.subscriptionLocalPublicSubmissionTitle),
                  subtitle: Text(
                    loc.subscriptionLocalPublicSubmissionQuota(
                      freeVersion.quotas['recommended_events'] ?? 0,
                      freeVersion.quotas['recommended_attractions'] ?? 0,
                    ),
                  ),
                ),
              ],
            ] else
              ...version.quotas.entries
                  .where(
                    (entry) =>
                        entry.key != SubscriptionResource.answerHistoryDays &&
                        shouldShowSubscriptionResource(
                          entry.key,
                          canUsePoints: canUsePoints,
                          canUseGame: canUseGame,
                        ),
                  )
                  .map((entry) {
                    final value = subscriptionQuotaValue(
                      loc,
                      entry.key,
                      entry.value,
                    );
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              subscriptionResourceLabel(loc, entry.key),
                            ),
                          ),
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
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
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
