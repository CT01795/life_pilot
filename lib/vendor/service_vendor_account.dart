import 'package:life_pilot/utils/supabase.dart';
import 'package:life_pilot/vendor/model_vendor_account.dart';
import 'package:life_pilot/vendor/model_vendor_dashboard.dart';
import 'package:life_pilot/vendor/repository_vendor_dashboard_cache.dart';
import 'package:life_pilot/event/model_event_item.dart';
import 'package:life_pilot/utils/text_normalization.dart';
import 'package:life_pilot/subscription/repository_pricing_catalog.dart';
import 'package:life_pilot/subscription/model_billing_cycle.dart';

class ServiceVendorAccount {
  RepositoryVendorDashboardCache get _dashboardCache =>
      RepositoryVendorDashboardCache(supabase);

  void cacheDashboard(ModelVendorDashboard value) =>
      _dashboardCache.write(value);

  void applySubmissionSaved({
    required EventItem? previous,
    required EventItem current,
    required bool attraction,
  }) => _dashboardCache.applySubmissionSaved(
    previous: previous,
    current: current,
    attraction: attraction,
  );

  void applySubmissionDeleted({
    required EventItem previous,
    required bool attraction,
  }) => _dashboardCache.applySubmissionDeleted(
    previous: previous,
    attraction: attraction,
  );

  Future<ModelVendorDashboard?> refreshRecentSubmissions() =>
      _dashboardCache.refreshRecentSubmissions();

  Future<void> addSpecialAuthorization({
    required String email,
    required DateTime endsAt,
    required int feeTwd,
    required Map<String, int> quotas,
  }) async {
    await supabase.rpc(
      'admin_add_vendor_special_authorization',
      params: {
        'p_email': email.trim(),
        'p_ends_at': endsAt.toUtc().toIso8601String(),
        'p_fee_twd': feeTwd,
        'p_quotas': quotas,
      },
    );
  }

  ServiceVendorAccount();

  Future<List<VendorPricingPlan>> fetchPricingPlans() async {
    final rows = await RepositoryPricingCatalog().read(vendor: true);
    return rows
        .map(
          (row) =>
              VendorPricingPlan.fromJson(Map<String, dynamic>.from(row as Map)),
        )
        .toList(growable: false);
  }

  Future<ModelVendorDashboard> fetchDashboard(
    String account, {
    bool force = false,
  }) async {
    final normalized = normalizeText(account);
    final client = supabase;
    if (normalizeText(client.auth.currentUser?.email) != normalized ||
        normalized.isEmpty) {
      throw StateError('Account scope changed');
    }
    final cache = RepositoryVendorDashboardCache(client);
    if (!force) {
      final cached = cache.read();
      if (cached != null) return cached;
    }
    final now = DateTime.now();
    final value = await client.rpc(
      'get_my_vendor_dashboard_bootstrap',
      params: {
        'p_day_start': DateTime(
          now.year,
          now.month,
          now.day,
        ).toUtc().toIso8601String(),
        'p_force_refresh': force,
      },
    );
    if (normalizeText(client.auth.currentUser?.email) != normalized) {
      throw StateError('Account scope changed');
    }
    if (value is! Map) {
      throw const FormatException('Invalid vendor dashboard');
    }
    final payload = Map<String, dynamic>.from(value);
    final status = payload['status'];
    final metrics = payload['metrics'];
    final plans = payload['plans'];
    if (status is! Map || metrics is! Map || plans is! List) {
      throw const FormatException('Invalid vendor dashboard');
    }
    final dashboard = ModelVendorDashboard(
      status: VendorSubscriptionStatus.fromJson(
        Map<String, dynamic>.from(status),
      ),
      metrics: VendorContentMetrics.fromSummary(
        Map<String, dynamic>.from(metrics),
      ),
      plans: plans
          .map(
            (row) => VendorPricingPlan.fromJson(
              Map<String, dynamic>.from(row as Map),
            ),
          )
          .toList(growable: false),
    );
    cache.write(dashboard);
    return dashboard;
  }

  Future<void> createPricingVersionAsAdmin({
    required String planCode,
    required String versionName,
    required DateTime effectiveAt,
    required int quarterlyPriceTwd,
    required int eventQuota,
    required int attractionQuota,
    required int imageMegabytes,
    required int analyticsDays,
    BillingCycle billingCycle = BillingCycle.month,
  }) async {
    await RepositoryPricingCatalog().save(
      vendor: true,
      payload: {
        'billing_cycle': billingCycle.name,
        'p_plan_code': planCode,
        'p_version_name': versionName.trim(),
        'p_effective_at': effectiveAt.toUtc().toIso8601String(),
        'p_quarterly_price_twd': quarterlyPriceTwd,
        'p_event_quota': eventQuota,
        'p_attraction_quota': attractionQuota,
        'p_image_megabytes': imageMegabytes,
        'p_analytics_days': analyticsDays,
      },
    );
  }

  Future<void> updatePricingVersionAsAdmin({
    required String pricingVersionId,
    required String planCode,
    required String versionName,
    required DateTime effectiveAt,
    required int quarterlyPriceTwd,
    required int eventQuota,
    required int attractionQuota,
    required int imageMegabytes,
    required int analyticsDays,
    BillingCycle billingCycle = BillingCycle.month,
  }) async {
    await RepositoryPricingCatalog().save(
      vendor: true,
      versionId: pricingVersionId,
      payload: {
        'billing_cycle': billingCycle.name,
        'p_plan_code': planCode,
        'p_version_name': versionName.trim(),
        'p_effective_at': effectiveAt.toUtc().toIso8601String(),
        'p_quarterly_price_twd': quarterlyPriceTwd,
        'p_event_quota': eventQuota,
        'p_attraction_quota': attractionQuota,
        'p_image_megabytes': imageMegabytes,
        'p_analytics_days': analyticsDays,
      },
    );
  }

  Future<void> deletePricingVersionAsAdmin({
    required String pricingVersionId,
  }) async {
    RepositoryPricingCatalog().invalidate();
    try {
      await supabase.rpc(
        'admin_delete_vendor_pricing_version',
        params: {'p_pricing_version_id': pricingVersionId},
      );
    } finally {
      RepositoryPricingCatalog().invalidate();
    }
  }

  Future<void> setSubscriptionAsAdmin({
    required String email,
    required String pricingVersionId,
    required int quotaMultiplier,
    required DateTime currentPeriodEnd,
    String? note,
  }) async {
    await supabase.rpc(
      'admin_set_vendor_subscription',
      params: {
        'p_email': normalizeText(email),
        'p_pricing_version_id': pricingVersionId,
        'p_quota_multiplier': quotaMultiplier,
        'p_current_period_end': currentPeriodEnd.toUtc().toIso8601String(),
        'p_admin_note': note?.trim(),
      },
    );
  }
}
