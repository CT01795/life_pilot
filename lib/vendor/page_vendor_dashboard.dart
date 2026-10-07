import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:life_pilot/apps/controller_page_main.dart';
import 'package:life_pilot/auth/controller_auth.dart';
import 'package:life_pilot/event/controller_event.dart';
import 'package:life_pilot/event/model_event.dart';
import 'package:life_pilot/event/model_event_item.dart';
import 'package:life_pilot/event/page_event_add.dart';
import 'package:life_pilot/event/service_event.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/utils/const.dart';
import 'package:life_pilot/utils/enum.dart';
import 'package:life_pilot/utils/service/service_weather.dart';
import 'package:life_pilot/vendor/model_vendor_account.dart';
import 'package:life_pilot/vendor/service_vendor_account.dart';
import 'package:life_pilot/vendor/vendor_plan_labels.dart';
import 'package:life_pilot/vendor/widgets_admin_vendor_pricing.dart';
import 'package:life_pilot/utils/widgets/widgets_adaptive_button.dart';
import 'package:provider/provider.dart';

class PageVendorDashboard extends StatefulWidget {
  const PageVendorDashboard({super.key, this.focusPricing = false});

  final bool focusPricing;

  @override
  State<PageVendorDashboard> createState() => _PageVendorDashboardState();
}

class _PageVendorDashboardState extends State<PageVendorDashboard> {
  final _service = ServiceVendorAccount();
  final _pricingKey = GlobalKey();
  late Future<_VendorDashboardData> _data;
  bool _pricingFocused = false;

  @override
  void initState() {
    super.initState();
    _data = _load();
  }

  Future<_VendorDashboardData> _load() async {
    final account = context.read<ControllerAuth>().currentAccount ?? '';
    await _service.ensureVendorAccount();
    final status = await _service.fetchMyStatus();
    final values = await Future.wait<dynamic>([
      _service.fetchMetrics(account),
      _service.fetchEngagementMetrics(
        fallbackAnalyticsDays: status.plan.analyticsDays,
      ),
      _service.fetchPricingPlans(),
    ]);
    final plans =
        List<VendorPricingPlan>.from(values[2] as List<VendorPricingPlan>)
          ..sort((left, right) {
            const order = {'free': 0, 'partner': 1, 'growth': 2};
            final byPlan = (order[left.code] ?? 99).compareTo(
              order[right.code] ?? 99,
            );
            if (byPlan != 0) return byPlan;
            return right.effectiveAt.compareTo(left.effectiveAt);
          });
    return _VendorDashboardData(
      metrics: values[0] as VendorContentMetrics,
      engagement: values[1] as VendorEngagementMetrics,
      status: status,
      plans: plans,
    );
  }

  void _reload() => setState(() => _data = _load());

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          _reload();
          await _data;
        },
        child: FutureBuilder<_VendorDashboardData>(
          future: _data,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError || snapshot.data == null) {
              return ListView(
                children: [
                  const SizedBox(height: 120),
                  Icon(
                    Icons.cloud_off_outlined,
                    size: 48,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  Gaps.h12,
                  Center(child: Text(loc.vendorDashboardLoadFailed)),
                  Gaps.h12,
                  Center(
                    child: FilledButton.icon(
                      onPressed: _reload,
                      icon: const Icon(Icons.refresh),
                      label: AdaptiveButtonLabel(loc.retry),
                    ),
                  ),
                ],
              );
            }
            if (widget.focusPricing && !_pricingFocused) {
              _pricingFocused = true;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                final pricingContext = _pricingKey.currentContext;
                if (pricingContext == null) return;
                Scrollable.ensureVisible(
                  pricingContext,
                  duration: const Duration(milliseconds: 350),
                  curve: Curves.easeOutCubic,
                  alignment: 0.05,
                );
              });
            }
            return _content(loc, snapshot.data!);
          },
        ),
      ),
    );
  }

  Widget _content(AppLocalizations loc, _VendorDashboardData data) {
    final theme = Theme.of(context);
    final status = data.status;
    final isAdmin = context.watch<ControllerAuth>().isSysAdmin;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _hero(loc, status),
        Gaps.h16,
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth >= 720
                ? (constraints.maxWidth - 36) / 4
                : (constraints.maxWidth - 12) / 2;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _metric(
                  width,
                  Icons.public,
                  loc.publishedSubmission,
                  data.metrics.published,
                ),
                _metric(
                  width,
                  Icons.hourglass_top,
                  loc.unpublishedSubmission,
                  data.metrics.pending,
                ),
                _metric(
                  width,
                  Icons.event_available,
                  loc.vendorActiveActivities,
                  data.metrics.activeEvents,
                ),
                _metric(
                  width,
                  Icons.place_outlined,
                  loc.vendorActiveAttractions,
                  data.metrics.activeAttractions,
                ),
              ],
            );
          },
        ),
        if (data.metrics.pending > 0) ...[
          Gaps.h12,
          _reviewStatus(loc, data.metrics.pending),
        ],
        Gaps.h12,
        _contentMix(loc, data.metrics),
        Gaps.h12,
        _recentSubmissions(loc, data.metrics.recentSubmissions),
        Gaps.h16,
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  loc.vendorCurrentPlan(
                    vendorPlanVersionName(loc, status.plan),
                  ),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Gaps.h8,
                _usage(
                  loc.vendorActiveActivities,
                  status.eventUsed,
                  isAdmin ? null : status.plan.eventQuota,
                ),
                _usage(
                  loc.vendorActiveAttractions,
                  status.attractionUsed,
                  isAdmin ? null : status.plan.attractionQuota,
                ),
                _usage(
                  loc.subscriptionImageStorage,
                  status.imageBytesUsed ~/ 1024 ~/ 1024,
                  isAdmin ? null : status.plan.imageMegabytes,
                  suffix: ' MB',
                ),
                if (!isAdmin) _quotaAction(loc, status),
              ],
            ),
          ),
        ),
        Gaps.h12,
        _engagementSection(loc, data.engagement),
        Gaps.h12,
        _nextStep(loc, data),
        Gaps.h24,
        Container(
          key: _pricingKey,
          child: Text(
            loc.vendorPricingTitle,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        Gaps.h4,
        Text(loc.vendorPricingDescription),
        if (isAdmin) ...[
          Gaps.h12,
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              onPressed: _openVendorPlanManager,
              icon: const Icon(Icons.admin_panel_settings_outlined),
              label: AdaptiveButtonLabel(loc.adminVendorPricingTitle),
            ),
          ),
        ],
        Gaps.h12,
        LayoutBuilder(
          builder: (context, constraints) {
            final cardWidth = constraints.maxWidth >= 900
                ? (constraints.maxWidth - 24) / 3
                : constraints.maxWidth;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: data.plans
                  .map(
                    (plan) => SizedBox(
                      width: cardWidth,
                      child: _VendorPlanCard(
                        plan: plan,
                        selected: plan.code == status.plan.code,
                        onTap: isAdmin ? _openVendorPlanManager : null,
                      ),
                    ),
                  )
                  .toList(growable: false),
            );
          },
        ),
        Gaps.h12,
        Text(loc.vendorPricingActiveOnlyNote, style: theme.textTheme.bodySmall),
      ],
    );
  }

  Widget _hero(AppLocalizations loc, VendorSubscriptionStatus status) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [colors.primaryContainer, colors.tertiaryContainer],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final title = Row(
                  children: [
                    Icon(Icons.storefront_outlined, color: colors.primary),
                    Gaps.w8,
                    Expanded(
                      child: Text(
                        loc.vendorDashboardTitle,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                );
                final plan = Chip(
                  avatar: const Icon(Icons.verified_outlined, size: 17),
                  label: Text(
                    vendorPlanVersionName(loc, status.plan),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                );
                if (constraints.maxWidth < 520) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      title,
                      Gaps.h8,
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: constraints.maxWidth,
                        ),
                        child: plan,
                      ),
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: title),
                    Gaps.w8,
                    plan,
                  ],
                );
              },
            ),
            Gaps.h8,
            Text(loc.vendorDashboardSubtitle),
            Gaps.h12,
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                FilledButton.icon(
                  onPressed: () => _openSubmission(TableNames.recommendEvents),
                  icon: const Icon(Icons.add_circle_outline),
                  label: AdaptiveButtonLabel(loc.vendorSubmitActivity),
                ),
                FilledButton.tonalIcon(
                  onPressed: () => _openSubmission(TableNames.recommendPlaces),
                  icon: const Icon(Icons.add_location_alt_outlined),
                  label: AdaptiveButtonLabel(loc.vendorSubmitAttraction),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _reviewStatus(AppLocalizations loc, int pending) => Card(
    color: Theme.of(context).colorScheme.secondaryContainer,
    child: ListTile(
      leading: const Icon(Icons.fact_check_outlined),
      title: Text(
        loc.vendorPendingReviewCount(pending),
        style: const TextStyle(fontWeight: FontWeight.w800),
      ),
      subtitle: Text(loc.vendorPendingReviewHint),
      trailing: const Icon(Icons.chevron_right),
      onTap: _openActivities,
    ),
  );

  Widget _contentMix(AppLocalizations loc, VendorContentMetrics metrics) {
    final total = metrics.activeEvents + metrics.activeAttractions;
    final publishedTotal = metrics.published + metrics.pending;
    final activityRatio = total == 0 ? 0.0 : metrics.activeEvents / total;
    final publishedRatio = publishedTotal == 0
        ? 0.0
        : metrics.published / publishedTotal;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              loc.vendorContentMixTitle,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
            ),
            Gaps.h12,
            _mixLine(
              loc.vendorActivityAttractionMix(
                metrics.activeEvents,
                metrics.activeAttractions,
              ),
              activityRatio,
            ),
            Gaps.h12,
            _mixLine(
              loc.vendorPublishedPendingMix(metrics.published, metrics.pending),
              publishedRatio,
            ),
          ],
        ),
      ),
    );
  }

  Widget _mixLine(String label, double value) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label),
      Gaps.h4,
      LinearProgressIndicator(value: value),
    ],
  );

  Widget _recentSubmissions(
    AppLocalizations loc,
    List<VendorRecentSubmission> submissions,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              loc.vendorRecentSubmissionsTitle,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
            ),
            Gaps.h8,
            if (submissions.isEmpty)
              Text(loc.vendorRecentSubmissionsEmpty)
            else
              ...submissions.map((submission) {
                final date = submission.startDate ?? submission.endDate;
                final details = <String>[
                  submission.isActivity
                      ? loc.vendorActivityLabel
                      : loc.vendorAttractionLabel,
                  if (submission.city.trim().isNotEmpty) submission.city.trim(),
                  if (date != null) DateFormat.yMd(loc.localeName).format(date),
                ].join(' · ');
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    submission.isActivity
                        ? Icons.event_outlined
                        : Icons.place_outlined,
                  ),
                  title: Text(
                    submission.name.trim().isEmpty
                        ? loc.vendorUntitledSubmission
                        : submission.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(details),
                  trailing: Chip(
                    visualDensity: VisualDensity.compact,
                    label: Text(
                      submission.isApproved
                          ? loc.publishedSubmission
                          : loc.unpublishedSubmission,
                    ),
                  ),
                  onTap: () => _openContent(submission.isActivity),
                );
              }),
          ],
        ),
      ),
    );
  }

  void _openContent(bool isActivity) =>
      context.read<ControllerPageMain>().changePage(
        isActivity ? PageType.recommendEvent : PageType.recommendPlaces,
      );

  Widget _quotaAction(AppLocalizations loc, VendorSubscriptionStatus status) {
    double ratio(int used, int quota) => quota <= 0 ? 0 : used / quota;
    final highest = [
      ratio(status.eventUsed, status.plan.eventQuota),
      ratio(status.attractionUsed, status.plan.attractionQuota),
      ratio(status.imageBytesUsed, status.plan.imageMegabytes * 1024 * 1024),
    ].reduce((left, right) => left > right ? left : right);
    if (highest < 0.8) return const SizedBox.shrink();
    final full = highest >= 1;
    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded),
          Gaps.w8,
          Expanded(
            child: Text(
              full ? loc.vendorQuotaFullHint : loc.vendorQuotaNearFullHint,
            ),
          ),
          TextButton(
            onPressed: _scrollToPricing,
            child: AdaptiveButtonLabel(loc.vendorViewPlans),
          ),
        ],
      ),
    );
  }

  void _scrollToPricing() {
    final pricingContext = _pricingKey.currentContext;
    if (pricingContext == null) return;
    Scrollable.ensureVisible(
      pricingContext,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
      alignment: 0.05,
    );
  }

  Widget _nextStep(AppLocalizations loc, _VendorDashboardData data) {
    final metrics = data.metrics;
    final engagement = data.engagement;
    final (icon, title, message) = switch ((
      metrics.activeEvents + metrics.activeAttractions,
      metrics.pending,
      engagement.pageViews,
      engagement.cardClicks,
      engagement.registrationClicks,
    )) {
      (0, _, _, _, _) => (
        Icons.rocket_launch_outlined,
        loc.vendorNextStepFirstTitle,
        loc.vendorNextStepFirstMessage,
      ),
      (_, > 0, _, _, _) => (
        Icons.schedule_outlined,
        loc.vendorNextStepReviewTitle,
        loc.vendorNextStepReviewMessage,
      ),
      (_, _, 0, _, _) => (
        Icons.photo_camera_outlined,
        loc.vendorNextStepExposureTitle,
        loc.vendorNextStepExposureMessage,
      ),
      (_, _, _, 0, _) => (
        Icons.ads_click_outlined,
        loc.vendorNextStepClickTitle,
        loc.vendorNextStepClickMessage,
      ),
      (_, _, _, _, 0) => (
        Icons.link_outlined,
        loc.vendorNextStepRegistrationTitle,
        loc.vendorNextStepRegistrationMessage,
      ),
      _ => (
        Icons.trending_up,
        loc.vendorNextStepGrowingTitle,
        loc.vendorNextStepGrowingMessage,
      ),
    };
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(child: Icon(icon)),
            Gaps.w12,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Gaps.h4,
                  Text(message),
                  Gaps.h12,
                  TextButton.icon(
                    onPressed: _openActivities,
                    icon: const Icon(Icons.arrow_forward),
                    label: AdaptiveButtonLabel(loc.vendorManageActivities),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openActivities() =>
      context.read<ControllerPageMain>().changePage(PageType.recommendEvent);

  Future<void> _openSubmission(String tableName) async {
    final controller = ControllerEvent(
      auth: context.read<ControllerAuth>(),
      serviceEvent: context.read<ServiceEvent>(),
      serviceWeather: context.read<ServiceWeather>(),
      tableName: tableName,
      toTableName: TableNames.calendarEvents,
      modelEvent: ModelEvent(),
    );
    try {
      final event = await Navigator.of(context).push<EventItem?>(
        MaterialPageRoute(
          builder: (_) => PageEventAdd(controllerEvent: controller),
        ),
      );
      if (event == null || !mounted) return;
      await context.read<ControllerAuth>().refreshSubscriptionUsage();
      _reload();
    } finally {
      controller.dispose();
    }
  }

  Future<void> _openVendorPlanManager() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            16,
            0,
            16,
            MediaQuery.viewInsetsOf(context).bottom + 24,
          ),
          child: const AdminVendorPricing(),
        ),
      ),
    );
    if (mounted) _reload();
  }

  Widget _engagementSection(
    AppLocalizations loc,
    VendorEngagementMetrics metrics,
  ) {
    final theme = Theme.of(context);
    final items = <(IconData, String, int)>[
      (
        Icons.visibility_outlined,
        loc.vendorAnalyticsPageViews,
        metrics.pageViews,
      ),
      (
        Icons.touch_app_outlined,
        loc.vendorAnalyticsCardClicks,
        metrics.cardClicks,
      ),
      (
        Icons.how_to_reg_outlined,
        loc.vendorAnalyticsRegistrationClicks,
        metrics.registrationClicks,
      ),
      (Icons.bookmark_border, loc.vendorAnalyticsSaves, metrics.saves),
      (Icons.thumb_up_alt_outlined, loc.vendorAnalyticsLikes, metrics.likes),
      (
        Icons.thumb_down_alt_outlined,
        loc.vendorAnalyticsDislikes,
        metrics.dislikes,
      ),
    ];
    final hasEngagement = items.any((item) => item.$3 > 0);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              loc.vendorAnalyticsTitle,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            Gaps.h4,
            Text(loc.vendorAnalyticsDescription(metrics.analyticsDays)),
            if (!hasEngagement) ...[
              Gaps.h16,
              Center(
                child: Column(
                  children: [
                    const Icon(Icons.insights_outlined, size: 40),
                    Gaps.h8,
                    Text(loc.vendorAnalyticsEmpty, textAlign: TextAlign.center),
                    Gaps.h8,
                    FilledButton.tonalIcon(
                      onPressed: () =>
                          _openSubmission(TableNames.recommendEvents),
                      icon: const Icon(Icons.add_circle_outline),
                      label: AdaptiveButtonLabel(loc.vendorSubmitActivity),
                    ),
                  ],
                ),
              ),
            ] else ...[
              Gaps.h12,
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _rateChip(
                    Icons.ads_click_outlined,
                    loc.vendorClickThroughRate,
                    metrics.cardClicks,
                    metrics.pageViews,
                  ),
                  _rateChip(
                    Icons.how_to_reg_outlined,
                    loc.vendorRegistrationRate,
                    metrics.registrationClicks,
                    metrics.cardClicks,
                  ),
                  Chip(
                    avatar: const Icon(Icons.favorite_border, size: 17),
                    label: Text(
                      loc.vendorPositiveActions(metrics.saves + metrics.likes),
                    ),
                  ),
                ],
              ),
              Gaps.h12,
              LayoutBuilder(
                builder: (context, constraints) {
                  final columns = constraints.maxWidth >= 720 ? 3 : 2;
                  final width =
                      (constraints.maxWidth - (columns - 1) * 10) / columns;
                  return Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: items
                        .map(
                          (item) => SizedBox(
                            width: width,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color:
                                    theme.colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Row(
                                  children: [
                                    Icon(item.$1, size: 20),
                                    Gaps.w8,
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '${item.$3}',
                                            style: theme.textTheme.titleMedium
                                                ?.copyWith(
                                                  fontWeight: FontWeight.w900,
                                                ),
                                          ),
                                          Text(
                                            item.$2,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        )
                        .toList(growable: false),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _rateChip(
    IconData icon,
    String label,
    int numerator,
    int denominator,
  ) {
    final rate = denominator <= 0 ? 0 : numerator / denominator * 100;
    return Chip(
      avatar: Icon(icon, size: 17),
      label: Text('$label ${rate.toStringAsFixed(1)}%'),
    );
  }

  Widget _metric(double width, IconData icon, String label, int value) {
    return SizedBox(
      width: width,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon),
              Gaps.h8,
              Text('$value', style: Theme.of(context).textTheme.headlineSmall),
              Text(label),
            ],
          ),
        ),
      ),
    );
  }

  Widget _usage(String label, int used, int? quota, {String suffix = ''}) {
    final progress = quota == null || quota <= 0
        ? 0.0
        : (used / quota).clamp(0.0, 1.0);
    final remaining = quota == null
        ? null
        : (quota - used < 0 ? 0 : quota - used);
    final nearlyFull = quota != null && quota > 0 && progress >= 0.8;
    final loc = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(label)),
              Text(quota == null ? '$used / ∞' : '$used / $quota$suffix'),
            ],
          ),
          if (remaining != null) ...[
            Gaps.h4,
            Text(
              loc.vendorQuotaRemaining(remaining, suffix),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: nearlyFull
                    ? Theme.of(context).colorScheme.error
                    : Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: nearlyFull ? FontWeight.w800 : null,
              ),
            ),
          ],
          Gaps.h4,
          if (quota != null) LinearProgressIndicator(value: progress),
        ],
      ),
    );
  }
}

class _VendorPlanCard extends StatelessWidget {
  const _VendorPlanCard({
    required this.plan,
    required this.selected,
    this.onTap,
  });

  final VendorPricingPlan plan;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    return Card(
      color: selected ? colors.primaryContainer : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: selected
            ? BorderSide(color: colors.primary, width: 2)
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      vendorPlanVersionName(loc, plan),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  if (selected) Icon(Icons.check_circle, color: colors.primary),
                ],
              ),
              Gaps.h8,
              Text(
                plan.quarterlyPriceTwd == 0
                    ? loc.free
                    : loc.vendorQuarterlyPrice(plan.quarterlyPriceTwd),
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const Divider(height: 24),
              Text(loc.vendorPlanActivityQuota(plan.eventQuota)),
              Text(loc.vendorPlanAttractionQuota(plan.attractionQuota)),
              Text(loc.vendorPlanImageQuota(plan.imageMegabytes)),
              Text(loc.vendorPlanAnalyticsDays(plan.analyticsDays)),
            ],
          ),
        ),
      ),
    );
  }
}

class _VendorDashboardData {
  const _VendorDashboardData({
    required this.metrics,
    required this.engagement,
    required this.status,
    required this.plans,
  });

  final VendorContentMetrics metrics;
  final VendorEngagementMetrics engagement;
  final VendorSubscriptionStatus status;
  final List<VendorPricingPlan> plans;
}
