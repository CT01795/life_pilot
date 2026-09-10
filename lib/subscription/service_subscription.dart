import 'package:life_pilot/subscription/model_subscription_usage.dart';
import 'package:life_pilot/utils/api.dart';

class ServiceSubscription {
  Future<SubscriptionSnapshot> fetchMyUsage() async {
    final responses = await Future.wait([
      supabase.rpc('get_my_subscription_usage'),
      supabase.rpc('get_my_subscription_status'),
      supabase.rpc('get_my_subscription_entitlements'),
    ]);
    final rows = responses.first;
    final statusRows = responses[1] as List<dynamic>;
    final entitlementRows = responses[2] as List<dynamic>;
    final status = statusRows.isEmpty
        ? <String, dynamic>{}
        : Map<String, dynamic>.from(statusRows.first as Map);
    final items = (rows as List<dynamic>)
        .map((row) => SubscriptionUsage.fromJson(
              Map<String, dynamic>.from(row as Map),
            ))
        .toList();
    final plan = status['plan']?.toString() ??
        (items.isEmpty
            ? 'free'
            : (rows.first as Map)['plan']?.toString() ?? 'free');
    return SubscriptionSnapshot(
      plan: plan,
      usage: {for (final item in items) item.resource: item},
      status: status['status']?.toString() ?? 'inactive',
      currentPeriodEnd: DateTime.tryParse(
        status['current_period_end']?.toString() ?? '',
      ),
      cancelAtPeriodEnd: status['cancel_at_period_end'] == true,
      storagePlan: status['storage_plan']?.toString() ?? 'cloud',
      quotaMultiplier: (status['quota_multiplier'] as num?)?.toInt() ?? 1,
      quarterlyPricePaidTwd:
          (status['quarterly_price_paid_twd'] as num?)?.toInt(),
      pricingVersionName: status['pricing_version_name']?.toString(),
      pricingEffectiveAt: DateTime.tryParse(
        status['pricing_effective_at']?.toString() ?? '',
      ),
      lastDataActivityAt: DateTime.tryParse(
        status['last_data_activity_at']?.toString() ?? '',
      ),
      downgradeGraceEndsAt: DateTime.tryParse(
        status['downgrade_grace_ends_at']?.toString() ?? '',
      ),
      entitlements: entitlementRows
          .map((row) => SubscriptionEntitlement.fromJson(
                Map<String, dynamic>.from(row as Map),
              ))
          .toList(),
    );
  }

  Future<void> setUserSubscriptionAsAdmin({
    required String email,
    required String plan,
    required DateTime expiresAt,
    required String note,
    required bool unlimited,
    Map<String, int?> quotas = const {},
  }) async {
    await supabase.rpc('admin_set_user_subscription', params: {
      'p_email': email.trim(),
      'p_plan': plan,
      'p_expires_at': expiresAt.toUtc().toIso8601String(),
      'p_admin_note': note.trim(),
      'p_unlimited_quota': unlimited,
      'p_calendar_quota': quotas['calendar'],
      'p_accounting_quota': quotas['accounting'],
      'p_point_quota': quotas['point'],
      'p_memory_quota': quotas['memory'],
      'p_game_question_quota': quotas['game'],
      'p_calendar_share_quota': quotas['share'],
      'p_image_megabytes': quotas['image'],
    });
  }

  Future<void> setUserSubscriptionV2AsAdmin({
    required String email,
    required String plan,
    required String storagePlan,
    required String? pricingVersionId,
    required int multiplier,
    required DateTime? expiresAt,
    required String note,
  }) async {
    await supabase.rpc('admin_set_user_subscription_v2', params: {
      'p_email': email.trim(),
      'p_plan': plan,
      'p_storage_plan': storagePlan,
      'p_pricing_version_id': pricingVersionId,
      'p_quota_multiplier': multiplier,
      'p_expires_at': expiresAt?.toUtc().toIso8601String(),
      'p_admin_note': note.trim(),
    });
  }

  Future<void> addUserEntitlementAsAdmin({
    required String email,
    required String storagePlan,
    required String pricingVersionId,
    required int multiplier,
    required DateTime endsAt,
    required String note,
  }) async {
    await supabase.rpc('admin_add_user_subscription_entitlement', params: {
      'p_email': email.trim(),
      'p_storage_plan': storagePlan,
      'p_pricing_version_id': pricingVersionId,
      'p_quota_multiplier': multiplier,
      'p_ends_at': endsAt.toUtc().toIso8601String(),
      'p_admin_note': note.trim(),
    });
  }

  Future<List<SubscriptionPricingVersion>> fetchPricingVersions() async {
    final rows = await supabase.rpc('get_subscription_pricing_versions');
    return (rows as List<dynamic>)
        .map((row) => SubscriptionPricingVersion.fromJson(
              Map<String, dynamic>.from(row as Map),
            ))
        .toList();
  }

  Future<void> createPricingVersionAsAdmin({
    required String name,
    required String storagePlan,
    required DateTime effectiveAt,
    required int quarterlyPrice,
    required Map<String, int> quotas,
  }) async {
    await supabase.rpc('admin_create_subscription_pricing_version', params: {
      'p_version_name': name.trim(),
      'p_storage_plan': storagePlan,
      'p_effective_at': effectiveAt.toUtc().toIso8601String(),
      'p_quarterly_price_twd': quarterlyPrice,
      'p_calendar_quota': quotas['calendar'],
      'p_accounting_quota': quotas['accounting'],
      'p_point_quota': quotas['point'],
      'p_memory_quota': quotas['memory'],
      'p_game_question_quota': quotas['game'],
      'p_calendar_share_quota': quotas['share'],
      'p_image_megabytes': quotas['image'],
      'p_answer_history_days': quotas['answerDays'],
    });
  }
}

class SubscriptionPricingVersion {
  const SubscriptionPricingVersion({
    required this.id,
    required this.name,
    required this.storagePlan,
    required this.effectiveAt,
    required this.quarterlyPriceTwd,
    required this.quotas,
  });

  final String id;
  final String name;
  final String storagePlan;
  final DateTime effectiveAt;
  final int quarterlyPriceTwd;
  final Map<String, int> quotas;

  factory SubscriptionPricingVersion.fromJson(Map<String, dynamic> json) =>
      SubscriptionPricingVersion(
        id: json['id'].toString(),
        name: json['version_name']?.toString() ?? '',
        storagePlan: json['storage_plan']?.toString() ?? 'cloud',
        effectiveAt: DateTime.parse(json['effective_at'].toString()),
        quarterlyPriceTwd: (json['quarterly_price_twd'] as num?)?.toInt() ?? 0,
        quotas: {
          'calendar_events': (json['calendar_quota'] as num?)?.toInt() ?? 0,
          'accounting_detail': (json['accounting_quota'] as num?)?.toInt() ?? 0,
          'point_record_detail': (json['point_quota'] as num?)?.toInt() ?? 0,
          'memory_trace': (json['memory_quota'] as num?)?.toInt() ?? 0,
          'game_questions': (json['game_question_quota'] as num?)?.toInt() ?? 0,
          'calendar_shares':
              (json['calendar_share_quota'] as num?)?.toInt() ?? 0,
          'image_bytes':
              ((json['image_megabytes'] as num?)?.toInt() ?? 0) * 1024 * 1024,
          'answer_history_days':
              (json['answer_history_days'] as num?)?.toInt() ?? 0,
        },
      );
}

class SubscriptionLimitException implements Exception {
  const SubscriptionLimitException(
    this.resource, {
    this.plusRequired = false,
    this.used,
    this.quota,
  });

  final String resource;
  final bool plusRequired;
  final int? used;
  final int? quota;

  static SubscriptionLimitException? tryParse(Object error) {
    final message = error.toString();
    const quotaMarker = 'LIFE_PILOT_QUOTA_REACHED:';
    const plusMarker = 'LIFE_PILOT_PLUS_REQUIRED:';
    if (message.contains(quotaMarker)) {
      final value =
          message.split(quotaMarker).last.split(RegExp(r"[\s,)]")).first;
      final parts = value.split(':');
      return SubscriptionLimitException(
        parts.first,
        used: parts.length > 1 ? int.tryParse(parts[1]) : null,
        quota: parts.length > 2 ? int.tryParse(parts[2]) : null,
      );
    }
    if (message.contains(plusMarker)) {
      return SubscriptionLimitException(
        message.split(plusMarker).last.split(RegExp(r"[\s,)]")).first,
        plusRequired: true,
      );
    }
    return null;
  }
}
