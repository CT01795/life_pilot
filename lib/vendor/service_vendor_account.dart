import 'package:life_pilot/utils/api.dart';
import 'package:life_pilot/utils/const.dart';
import 'package:life_pilot/vendor/model_vendor_account.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ServiceVendorAccount {
  static final _fallbackPlans = <VendorPricingPlan>[
    VendorSubscriptionStatus.free.plan,
    VendorPricingPlan(
      id: 'partner',
      code: 'partner',
      versionName: 'Partner 2026-Q4',
      effectiveAt: DateTime.utc(2026, 10, 1),
      quarterlyPriceTwd: 299,
      eventQuota: 30,
      attractionQuota: 10,
      imageMegabytes: 300,
      analyticsDays: 90,
    ),
    VendorPricingPlan(
      id: 'growth',
      code: 'growth',
      versionName: 'Growth 2026-Q4',
      effectiveAt: DateTime.utc(2026, 10, 1),
      quarterlyPriceTwd: 699,
      eventQuota: 100,
      attractionQuota: 30,
      imageMegabytes: 1024,
      analyticsDays: 365,
    ),
  ];

  Future<void> ensureVendorAccount() async {
    try {
      await supabase.rpc('ensure_my_vendor_account');
    } on PostgrestException catch (error) {
      if (error.code != '42883' && error.code != 'PGRST202') rethrow;
    }
  }

  Future<List<VendorPricingPlan>> fetchPricingPlans() async {
    try {
      final rows = await supabase.rpc('get_vendor_pricing_versions');
      final plans = (rows as List<dynamic>)
          .map(
            (row) => VendorPricingPlan.fromJson(
              Map<String, dynamic>.from(row as Map),
            ),
          )
          .toList(growable: false);
      return plans.isEmpty ? _fallbackPlans : plans;
    } on PostgrestException catch (error) {
      if (error.code == '42883' || error.code == 'PGRST202') {
        return _fallbackPlans;
      }
      rethrow;
    }
  }

  Future<VendorSubscriptionStatus> fetchMyStatus() async {
    try {
      final value = await supabase.rpc('get_my_vendor_subscription_status');
      if (value is Map) {
        return VendorSubscriptionStatus.fromJson(
          Map<String, dynamic>.from(value),
        );
      }
      return VendorSubscriptionStatus.free;
    } on PostgrestException catch (error) {
      if (error.code == '42883' || error.code == 'PGRST202') {
        return VendorSubscriptionStatus.free;
      }
      rethrow;
    }
  }

  Future<VendorContentMetrics> fetchMetrics(String account) async {
    final normalized = account.trim().toLowerCase();
    final responses = await Future.wait([
      supabase
          .from(TableNames.recommendEvents)
          .select('id,is_approved,start_date,end_date')
          .eq(Fields.account, normalized),
      supabase
          .from(TableNames.recommendPlaces)
          .select('id,is_approved,start_date,end_date')
          .eq(Fields.account, normalized),
    ]);
    final eventRows = (responses[0] as List<dynamic>)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList(growable: false);
    final attractionRows = (responses[1] as List<dynamic>)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList(growable: false);
    final allRows = [...eventRows, ...attractionRows];
    final today = DateTime.now();
    final date = DateTime(today.year, today.month, today.day);
    bool active(Map<String, dynamic> row) {
      final end = DateTime.tryParse(
        row['end_date']?.toString() ?? row['start_date']?.toString() ?? '',
      );
      return end == null || !end.toLocal().isBefore(date);
    }

    return VendorContentMetrics(
      published: allRows.where((row) => row['is_approved'] == true).length,
      pending: allRows.where((row) => row['is_approved'] != true).length,
      activeEvents: eventRows.where(active).length,
      activeAttractions: attractionRows.where(active).length,
    );
  }

  Future<VendorEngagementMetrics> fetchEngagementMetrics({
    required int fallbackAnalyticsDays,
  }) async {
    try {
      final value = await supabase.rpc('get_my_vendor_content_analytics');
      if (value is Map) {
        return VendorEngagementMetrics.fromJson(
          Map<String, dynamic>.from(value),
        );
      }
    } on PostgrestException catch (error) {
      if (error.code != '42883' && error.code != 'PGRST202') rethrow;
    }
    return VendorEngagementMetrics.empty(analyticsDays: fallbackAnalyticsDays);
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
        'p_email': email.trim().toLowerCase(),
        'p_pricing_version_id': pricingVersionId,
        'p_quota_multiplier': quotaMultiplier,
        'p_current_period_end': currentPeriodEnd.toUtc().toIso8601String(),
        'p_admin_note': note?.trim(),
      },
    );
  }
}
