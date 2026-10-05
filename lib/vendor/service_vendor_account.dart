import 'package:life_pilot/utils/api.dart';
import 'package:life_pilot/utils/const.dart';
import 'package:life_pilot/vendor/model_vendor_account.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ServiceVendorAccount {
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
    final normalized = account.trim().toLowerCase();
    final responses = await Future.wait([
      supabase
          .from(TableNames.recommendEvents)
          .select('id,name,city,is_approved,start_date,end_date')
          .eq(Fields.account, normalized),
      supabase
          .from(TableNames.recommendPlaces)
          .select('id,name,city,is_approved,start_date,end_date')
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

    VendorRecentSubmission submission(
      Map<String, dynamic> row, {
      required bool isActivity,
    }) => VendorRecentSubmission(
      id: row['id']?.toString() ?? '',
      name: row['name']?.toString() ?? '',
      city: row['city']?.toString() ?? '',
      isActivity: isActivity,
      isApproved: row['is_approved'] == true,
      startDate: DateTime.tryParse(
        row['start_date']?.toString() ?? '',
      )?.toLocal(),
      endDate: DateTime.tryParse(row['end_date']?.toString() ?? '')?.toLocal(),
    );

    final recentSubmissions =
        <VendorRecentSubmission>[
          ...eventRows.map((row) => submission(row, isActivity: true)),
          ...attractionRows.map((row) => submission(row, isActivity: false)),
        ]..sort((left, right) {
          if (left.isApproved != right.isApproved) {
            return left.isApproved ? 1 : -1;
          }
          final leftDate = left.startDate ?? left.endDate;
          final rightDate = right.startDate ?? right.endDate;
          if (leftDate == null && rightDate == null) return 0;
          if (leftDate == null) return 1;
          if (rightDate == null) return -1;
          final leftUpcoming = !leftDate.isBefore(date);
          final rightUpcoming = !rightDate.isBefore(date);
          if (leftUpcoming != rightUpcoming) return leftUpcoming ? -1 : 1;
          return leftUpcoming
              ? leftDate.compareTo(rightDate)
              : rightDate.compareTo(leftDate);
        });

    return VendorContentMetrics(
      published: allRows.where((row) => row['is_approved'] == true).length,
      pending: allRows.where((row) => row['is_approved'] != true).length,
      activeEvents: eventRows.where(active).length,
      activeAttractions: attractionRows.where(active).length,
      recentSubmissions: recentSubmissions.take(5).toList(growable: false),
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
