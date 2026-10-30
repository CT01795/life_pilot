import 'package:life_pilot/event/service_content_performance.dart';
import 'package:life_pilot/utils/supabase.dart';
import 'package:life_pilot/vendor/model_vendor_account.dart';
import 'package:life_pilot/utils/text_normalization.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ServiceVendorAccount {
  final ServiceContentPerformance _performance;
  ServiceVendorAccount({ServiceContentPerformance? performance})
    : _performance = performance ?? ServiceContentPerformance();
  Future<void> ensureVendorAccount() async {
    try {
      await supabase.rpc('ensure_my_vendor_account');
    } on PostgrestException catch (error) {
      if (error.code != '42883' && error.code != 'PGRST202') rethrow;
    }
  }

  Future<List<VendorPricingPlan>> fetchPricingPlans() async {
    final rows = await supabase.rpc('get_vendor_pricing_versions');
    return (rows as List<dynamic>)
        .map(
          (row) =>
              VendorPricingPlan.fromJson(Map<String, dynamic>.from(row as Map)),
        )
        .toList(growable: false);
  }

  Future<VendorSubscriptionStatus> fetchMyStatus() async {
    final value = await supabase.rpc('get_my_vendor_subscription_status');
    if (value is! Map) throw StateError('vendor_subscription_status_missing');
    return VendorSubscriptionStatus.fromJson(Map<String, dynamic>.from(value));
  }

  Future<VendorContentMetrics> fetchMetrics(String account) async {
    final normalized = normalizeText(account);
    final responses = await Future.wait([
      _performance.read(
        owner: normalized,
        attractions: false,
        includeSubmissionDetails: true,
      ),
      _performance.read(
        owner: normalized,
        attractions: true,
        includeSubmissionDetails: true,
      ),
    ]);
    return VendorContentMetrics.fromPerformance(
      events: responses[0],
      attractions: responses[1],
      now: DateTime.now(),
    );
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
  }) async {
    await supabase.rpc(
      'admin_create_vendor_pricing_version',
      params: {
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
  }) async {
    await supabase.rpc(
      'admin_update_vendor_pricing_version',
      params: {
        'p_pricing_version_id': pricingVersionId,
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
    await supabase.rpc(
      'admin_delete_vendor_pricing_version',
      params: {'p_pricing_version_id': pricingVersionId},
    );
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
