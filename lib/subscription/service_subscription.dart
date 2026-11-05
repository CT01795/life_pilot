import 'package:life_pilot/subscription/model_subscription_usage.dart';
import 'package:life_pilot/subscription/model_subscription_cleanup_preview.dart';
export 'package:life_pilot/subscription/model_subscription_cleanup_preview.dart';
import 'package:life_pilot/subscription/repository_subscription_maintenance.dart';
import 'package:life_pilot/subscription/model_quota_free_period.dart';
export 'package:life_pilot/subscription/model_quota_free_period.dart';
import 'package:life_pilot/subscription/repository_subscription_bootstrap.dart';
import 'package:life_pilot/subscription/subscription_entitlement_quota.dart'
    show subscriptionQuotaResources;
import 'package:life_pilot/subscription/repository_pricing_catalog.dart';
import 'package:life_pilot/subscription/model_billing_cycle.dart';
import 'package:life_pilot/subscription/model_admin_subscription_overview.dart';
import 'package:life_pilot/subscription/repository_admin_subscription_overview.dart';
import 'package:life_pilot/utils/supabase.dart';
import 'package:life_pilot/utils/const.dart';
import 'package:life_pilot/utils/value_parser.dart';

class ServiceSubscription {
  Future<AdminSubscriptionOverview> fetchUserSubscriptionOverviewAsAdmin(
    String email,
  ) => RepositoryAdminSubscriptionOverview(supabase).read(email);

  Future<List<QuotaFreePeriod>> fetchQuotaFreePeriods() =>
      RepositorySubscriptionMaintenance(supabase).periods();

  Future<void> saveQuotaFreePeriodAsAdmin({
    String? id,
    required String name,
    required DateTime startsAt,
    required DateTime endsAt,
    required bool enabled,
    int? reminderDays,
    List<String> targetAccounts = const [],
  }) async {
    await RepositorySubscriptionMaintenance(supabase).savePeriod({
      'p_period_id': id,
      'p_name': name.trim(),
      'p_starts_at': startsAt.toUtc().toIso8601String(),
      'p_ends_at': endsAt.toUtc().toIso8601String(),
      'p_enabled': enabled,
      'p_reminder_days': reminderDays,
      'p_target_accounts': targetAccounts,
    });
  }

  Future<void> deleteQuotaFreePeriodAsAdmin(String id) async {
    await RepositorySubscriptionMaintenance(supabase).deletePeriod(id);
  }

  Future<Map<String, dynamic>?> fetchUserSubscriptionAsAdmin({
    required String email,
  }) async {
    final rows =
        await supabase.rpc(
              'admin_get_user_subscription',
              params: {'p_email': email.trim()},
            )
            as List<dynamic>;
    if (rows.isEmpty) return null;
    return Map<String, dynamic>.from(rows.first as Map);
  }

  Future<List<SubscriptionCleanupPreview>> fetchCleanupPreview({
    String? email,
  }) => RepositorySubscriptionMaintenance(supabase).preview(email);

  Future<Map<String, dynamic>> cleanupData({
    String? email,
    required String mode,
  }) => RepositorySubscriptionMaintenance(supabase).cleanup(email, mode);

  Future<SubscriptionSnapshot> fetchMyUsage({
    String storagePlan = 'cloud',
  }) async {
    final bootstrap = await RepositorySubscriptionBootstrap(
      supabase,
    ).read(storagePlan);
    final periods = bootstrap['quota_free_periods'];
    final usage = bootstrap['usage'];
    final rawStatus = bootstrap['status'];
    final entitlements = bootstrap['entitlements'];
    if (periods is! List ||
        usage is! List ||
        rawStatus is! Map ||
        rawStatus['status'] is! String ||
        rawStatus['plan'] is! String ||
        entitlements is! List) {
      throw const FormatException('Incomplete subscription bootstrap');
    }
    final promotionPeriods = List<QuotaFreePeriod>.unmodifiable(
      periods.map(
        (row) =>
            QuotaFreePeriod.fromJson(Map<String, dynamic>.from(row as Map)),
      ),
    );
    final rows = usage;
    final entitlementRows = entitlements;
    final status = Map<String, dynamic>.from(rawStatus);
    if (status['status'] == 'configuration_missing') {
      return SubscriptionSnapshot(
        plan: 'unconfigured',
        usage: const {},
        status: 'configuration_missing',
        storagePlan: storagePlan,
        entitlements: entitlementRows
            .map(
              (row) => SubscriptionEntitlement.fromJson(
                Map<String, dynamic>.from(row as Map),
              ),
            )
            .toList(growable: false),
        promotionPeriods: promotionPeriods,
      );
    }
    final rawQuotas = bootstrap['cumulative_quotas'];
    if (rawQuotas is! Map) {
      throw const FormatException('Missing cumulative quotas');
    }
    final cumulativeQuotas = <String, int>{
      for (final entry in rawQuotas.entries)
        entry.key as String: entry.value as int,
    };
    final recommendationUsage = <SubscriptionUsage>[];
    if (bootstrap['vendor'] != true) {
      final counts = bootstrap['recommendation_counts'];
      final quotas = storagePlan == 'cloud'
          ? cumulativeQuotas
          : bootstrap['cloud_recommendation_quotas'];
      if (counts is! List ||
          counts.length != 2 ||
          quotas is! Map ||
          counts.any((value) => value is! int) ||
          quotas['recommended_events'] is! int ||
          quotas['recommended_attractions'] is! int) {
        throw const FormatException('Missing recommendation quotas');
      }
      recommendationUsage.addAll([
        SubscriptionUsage(
          resource: 'recommended_events',
          used: counts[0] as int,
          quota: quotas['recommended_events'] as int,
        ),
        SubscriptionUsage(
          resource: 'recommended_attractions',
          used: counts[1] as int,
          quota: quotas['recommended_attractions'] as int,
        ),
      ]);
    }
    var items = <SubscriptionUsage>[
      ...rows.map(
        (row) =>
            SubscriptionUsage.fromJson(Map<String, dynamic>.from(row as Map)),
      ),
      ...recommendationUsage,
    ];
    // The currently selected storage location decides which entitlement set is
    // presented. Never infer it from the newest subscription row because users
    // may hold valid cloud and local subscriptions at the same time.
    if (storagePlan == 'cloud' && cumulativeQuotas.isNotEmpty) {
      items = items
          .map(
            (item) => cumulativeQuotas.containsKey(item.resource)
                ? SubscriptionUsage(
                    resource: item.resource,
                    used: item.used,
                    quota: cumulativeQuotas[item.resource]!,
                  )
                : item,
          )
          .toList(growable: true);
    }

    items.sort((a, b) {
      const resourceOrder = [
        'calendar_events',
        'recommended_events',
        'recommended_attractions',
        'accounting_detail',
        'point_record_detail',
        'memory_trace',
        'game_questions',
        'calendar_shares',
        'image_bytes',
      ];

      final ai = resourceOrder.indexOf(a.resource);
      final bi = resourceOrder.indexOf(b.resource);

      final aIndex = ai == -1 ? resourceOrder.length : ai;
      final bIndex = bi == -1 ? resourceOrder.length : bi;

      return aIndex.compareTo(bIndex);
    });

    final statusPlan = parseStringValue(status['plan']);
    final plan = statusPlan.isNotEmpty
        ? statusPlan
        : (items.isEmpty
              ? 'free'
              : parseStringValue(
                  (rows.first as Map)['plan'],
                  fallback: 'free',
                ));
    return SubscriptionSnapshot(
      plan: plan,
      promotionPeriods: promotionPeriods,
      usage: {for (final item in items) item.resource: item},
      status: parseStringValue(status['status'], fallback: 'inactive'),
      currentPeriodEnd: tryParseDateTimeValue(status['current_period_end']),
      cancelAtPeriodEnd: status['cancel_at_period_end'] == true,
      storagePlan: parseStringValue(status['storage_plan'], fallback: 'cloud'),
      quotaMultiplier: parseIntValue(status['quota_multiplier'], fallback: 1),
      quarterlyPricePaidTwd: tryParseIntValue(
        status['quarterly_price_paid_twd'],
      ),
      pricingVersionName: parseStringValue(status['pricing_version_name']),
      pricingEffectiveAt: tryParseDateTimeValue(status['pricing_effective_at']),
      lastDataActivityAt: tryParseDateTimeValue(
        status['last_data_activity_at'],
      ),
      downgradeGraceEndsAt: tryParseDateTimeValue(
        status['downgrade_grace_ends_at'],
      ),
      entitlements: entitlementRows
          .map(
            (row) => SubscriptionEntitlement.fromJson(
              Map<String, dynamic>.from(row as Map),
            ),
          )
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
    await supabase.rpc(
      'admin_set_user_subscription',
      params: {
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
      },
    );
  }

  Future<void> extendUserSubscriptionAsAdmin({
    required String email,
    int days = 90,
  }) async {
    await supabase.rpc(
      'admin_extend_user_subscription',
      params: {'p_email': email.trim(), 'p_days': days},
    );
  }

  Future<void> deleteUserSubscriptionAsAdmin({required String email}) async {
    await supabase.rpc(
      'admin_delete_user_subscription',
      params: {'p_email': email.trim()},
    );
  }

  Future<List<Map<String, dynamic>>> fetchUserEntitlementsAsAdmin({
    required String email,
  }) async {
    final rows = await supabase.rpc(
      'admin_get_user_subscription_entitlements',
      params: {'p_email': email.trim()},
    );
    return (rows as List<dynamic>)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList(growable: false);
  }

  Future<void> deleteUserEntitlementAsAdmin({
    required String entitlementId,
  }) async {
    await supabase.rpc(
      'admin_delete_user_subscription_entitlement',
      params: {'p_entitlement_id': entitlementId},
    );
  }

  Future<void> updateUserEntitlementAsAdmin({
    required String entitlementId,
    required String storagePlan,
    required String pricingVersionId,
    required int multiplier,
    required DateTime endsAt,
    required String note,
  }) async {
    await supabase.rpc(
      'admin_update_user_subscription_entitlement',
      params: {
        'p_entitlement_id': entitlementId,
        'p_storage_plan': storagePlan,
        'p_pricing_version_id': pricingVersionId,
        'p_quota_multiplier': multiplier,
        'p_ends_at': endsAt.toUtc().toIso8601String(),
        'p_admin_note': note.trim(),
      },
    );
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
    await supabase.rpc(
      'admin_set_user_subscription_v2',
      params: {
        'p_email': email.trim(),
        'p_plan': plan,
        'p_storage_plan': storagePlan,
        'p_pricing_version_id': pricingVersionId,
        'p_quota_multiplier': multiplier,
        'p_expires_at': expiresAt?.toUtc().toIso8601String(),
        'p_admin_note': note.trim(),
      },
    );
  }

  Future<void> addPersonalSpecialAuthorization({
    required String email,
    required String storagePlan,
    required DateTime endsAt,
    required int feeTwd,
    required Map<String, int> quotas,
  }) async {
    await supabase.rpc(
      'admin_add_personal_special_authorization',
      params: {
        'p_email': email.trim(),
        'p_storage_plan': storagePlan,
        'p_ends_at': endsAt.toUtc().toIso8601String(),
        'p_fee_twd': feeTwd,
        'p_quotas': storagePlan == 'local'
            ? {for (final key in subscriptionQuotaResources) key: 0}
            : quotas,
      },
    );
  }

  Future<void> addUserEntitlementAsAdmin({
    required String email,
    required String storagePlan,
    required String pricingVersionId,
    required int multiplier,
    required DateTime endsAt,
    required String note,
  }) async {
    await supabase.rpc(
      'admin_add_user_subscription_entitlement',
      params: {
        'p_email': email.trim(),
        'p_storage_plan': storagePlan,
        'p_pricing_version_id': pricingVersionId,
        'p_quota_multiplier': multiplier,
        'p_ends_at': endsAt.toUtc().toIso8601String(),
        'p_admin_note': note.trim(),
      },
    );
  }

  Future<List<SubscriptionPricingVersion>> fetchPricingVersions({
    bool displayOnly = false,
  }) async {
    final rows = await RepositoryPricingCatalog().read(
      vendor: false,
      displayOnly: displayOnly,
    );
    return rows
        .map(
          (row) => SubscriptionPricingVersion.fromJson(
            Map<String, dynamic>.from(row as Map),
          ),
        )
        .toList();
  }

  Future<void> createPricingVersionAsAdmin({
    required String name,
    required String storagePlan,
    required DateTime effectiveAt,
    required int quarterlyPrice,
    required Map<String, int> quotas,
    BillingCycle billingCycle = BillingCycle.month,
  }) async {
    await RepositoryPricingCatalog().save(
      vendor: false,
      payload: {
        'billing_cycle': billingCycle.name,
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
        'p_recommended_event_quota': quotas['event'],
        'p_recommended_attraction_quota': quotas['attraction'],
        'p_image_megabytes': quotas['image'],
        'p_answer_history_days': quotas['answerDays'],
      },
    );
  }

  Future<void> updatePricingVersionAsAdmin({
    required String pricingVersionId,
    required String name,
    required String storagePlan,
    required DateTime effectiveAt,
    required int quarterlyPrice,
    required Map<String, int> quotas,
    BillingCycle billingCycle = BillingCycle.month,
  }) async {
    await RepositoryPricingCatalog().save(
      vendor: false,
      versionId: pricingVersionId,
      payload: {
        'billing_cycle': billingCycle.name,
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
        'p_recommended_event_quota': quotas['event'],
        'p_recommended_attraction_quota': quotas['attraction'],
        'p_image_megabytes': quotas['image'],
        'p_answer_history_days': quotas['answerDays'],
      },
    );
  }

  Future<void> deletePricingVersionAsAdmin({required String versionId}) async {
    RepositoryPricingCatalog().invalidate();
    try {
      await supabase.rpc(
        'admin_delete_subscription_pricing_version',
        params: {'p_pricing_version_id': versionId},
      );
    } finally {
      RepositoryPricingCatalog().invalidate();
    }
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
    this.billingCycle = BillingCycle.month,
  });

  final String id;
  final String name;
  final String storagePlan;
  final DateTime effectiveAt;
  final int quarterlyPriceTwd;
  // Legacy storage column name; amount is for billingCycle, never a conversion.
  int get priceTwd => quarterlyPriceTwd;
  final BillingCycle billingCycle;
  final Map<String, int> quotas;

  factory SubscriptionPricingVersion.fromJson(Map<String, dynamic> json) =>
      SubscriptionPricingVersion(
        id: parseStringValue(json[Fields.id]),
        name: parseStringValue(json['version_name']),
        storagePlan: parseStringValue(json['storage_plan'], fallback: 'cloud'),
        effectiveAt:
            tryParseDateTimeValue(json['effective_at']) ?? DateTime.now(),
        quarterlyPriceTwd: parseIntValue(json['quarterly_price_twd']),
        billingCycle: BillingCycle.from(json['billing_cycle']),
        quotas: {
          'calendar_events': parseIntValue(json['calendar_quota']),
          'recommended_events': parseIntValue(json['recommended_event_quota']),
          'recommended_attractions': parseIntValue(
            json['recommended_attraction_quota'],
          ),
          'accounting_detail': parseIntValue(json['accounting_quota']),
          'point_record_detail': parseIntValue(json['point_quota']),
          'memory_trace': parseIntValue(json['memory_quota']),
          'game_questions': parseIntValue(json['game_question_quota']),
          'calendar_shares': parseIntValue(json['calendar_share_quota']),
          'image_bytes': parseIntValue(json['image_megabytes']) * 1024 * 1024,
          'answer_history_days': parseIntValue(json['answer_history_days']),
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
      final value = message
          .split(quotaMarker)
          .last
          .split(RegExp(r"[\s,)]"))
          .first;
      final parts = value.split(':');
      return SubscriptionLimitException(
        parts.first,
        used: parts.length > 1 ? tryParseIntValue(parts[1]) : null,
        quota: parts.length > 2 ? tryParseIntValue(parts[2]) : null,
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
