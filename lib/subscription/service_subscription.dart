import 'package:life_pilot/subscription/model_subscription_usage.dart';
import 'package:life_pilot/utils/api.dart';
import 'package:life_pilot/utils/const.dart';
import 'package:life_pilot/utils/logger.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ServiceSubscription {
  Future<List<QuotaFreePeriod>> fetchQuotaFreePeriods() async {
    final rows = await supabase.rpc('get_quota_free_period');
    if (rows is! List) return const [];
    return rows
        .map(
          (row) =>
              QuotaFreePeriod.fromJson(Map<String, dynamic>.from(row as Map)),
        )
        .toList(growable: false);
  }

  Future<void> saveQuotaFreePeriodAsAdmin({
    String? id,
    required String name,
    required DateTime startsAt,
    required DateTime endsAt,
    required bool enabled,
    int? reminderDays,
    List<String> targetAccounts = const [],
  }) async {
    await supabase.rpc(
      'admin_set_quota_free_period',
      params: {
        'p_period_id': id,
        'p_name': name.trim(),
        'p_starts_at': startsAt.toUtc().toIso8601String(),
        'p_ends_at': endsAt.toUtc().toIso8601String(),
        'p_enabled': enabled,
        'p_reminder_days': reminderDays,
        'p_target_accounts': targetAccounts,
      },
    );
  }

  Future<void> deleteQuotaFreePeriodAsAdmin(String id) async {
    await supabase.rpc(
      'admin_delete_quota_free_period',
      params: {'p_period_id': id},
    );
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

  Future<List<Map<String, dynamic>>>
  fetchAllUserSubscriptionSummariesAsAdmin() async {
    final rows = await supabase.rpc('admin_list_user_subscription_summaries');
    return (rows as List<dynamic>)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList(growable: false);
  }

  Future<List<SubscriptionCleanupPreview>> fetchCleanupPreview({
    String? email,
  }) async {
    final rows = await supabase.rpc(
      'get_subscription_cleanup_preview',
      params: {'p_email': email?.trim()},
    );
    return (rows as List<dynamic>)
        .map(
          (row) => SubscriptionCleanupPreview.fromJson(
            Map<String, dynamic>.from(row as Map),
          ),
        )
        .toList(growable: false);
  }

  Future<Map<String, dynamic>> cleanupData({
    String? email,
    required String mode,
  }) async {
    final result = await supabase.rpc(
      'cleanup_subscription_data',
      params: {'p_email': email?.trim(), 'p_mode': mode},
    );
    return Map<String, dynamic>.from(result as Map);
  }

  Future<SubscriptionSnapshot> fetchMyUsage() async {
    final responses = await Future.wait<dynamic>([
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
    final recommendationUsage = await _fetchRecommendationUsage(
      entitlementRows,
      status,
    );
    var items = <SubscriptionUsage>[
      ...(rows as List<dynamic>).map(
        (row) =>
            SubscriptionUsage.fromJson(Map<String, dynamic>.from(row as Map)),
      ),
      ...recommendationUsage,
    ];
    final cumulativeQuotas = await _fetchCumulativeQuotas(
      storagePlan: status['storage_plan']?.toString() ?? 'cloud',
    );
    if (cumulativeQuotas.isNotEmpty) {
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

    final plan =
        status['plan']?.toString() ??
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
      quarterlyPricePaidTwd: (status['quarterly_price_paid_twd'] as num?)
          ?.toInt(),
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
          .map(
            (row) => SubscriptionEntitlement.fromJson(
              Map<String, dynamic>.from(row as Map),
            ),
          )
          .toList(),
    );
  }

  Future<Map<String, int>> _fetchCumulativeQuotas({
    required String storagePlan,
  }) async {
    try {
      final rows = await supabase.rpc(
        'get_my_cumulative_subscription_quotas',
        params: {'p_storage_plan': storagePlan},
      );
      return {
        for (final raw in rows as List<dynamic>)
          if (raw case final Map row)
            row['resource'].toString(): (row['quota'] as num?)?.toInt() ?? 0,
      };
    } on PostgrestException catch (error) {
      // Older databases continue using get_my_subscription_usage until the
      // cumulative-quota RPC is installed.
      if (error.code == '42883' || error.code == 'PGRST202') return const {};
      rethrow;
    }
  }

  Future<List<SubscriptionUsage>> _fetchRecommendationUsage(
    List<dynamic> entitlementRows,
    Map<String, dynamic> status,
  ) async {
    try {
      final account = supabase.auth.currentUser?.email?.toLowerCase();
      if (account == null || account.isEmpty) return const [];
      final now = DateTime.now();
      final today =
          '${now.year.toString().padLeft(4, '0')}-'
          '${now.month.toString().padLeft(2, '0')}-'
          '${now.day.toString().padLeft(2, '0')}';
      final results = await Future.wait<List<Map<String, dynamic>>>([
        supabase
            .from(TableNames.recommendEvents)
            .select('id')
            .ilike(Fields.account, account)
            .or('end_date.gte.$today,start_date.gte.$today'),
        supabase
            .from(TableNames.recommendPlaces)
            .select('id')
            .ilike(Fields.account, account)
            .or('end_date.gte.$today,start_date.gte.$today'),
      ]);

      var eventQuota = 0;
      var attractionQuota = 0;
      final activeCloudEntitlements = entitlementRows.where((raw) {
        final row = Map<String, dynamic>.from(raw as Map);
        final endsAt = DateTime.tryParse(row['ends_at']?.toString() ?? '');
        return row['storage_plan']?.toString() == 'cloud' &&
            endsAt != null &&
            endsAt.isAfter(now);
      });
      for (final raw in activeCloudEntitlements) {
        final row = Map<String, dynamic>.from(raw as Map);
        final snapshot = Map<String, dynamic>.from(
          row['entitlement_snapshot'] as Map? ?? const {},
        );
        final multiplier =
            (row['quota_multiplier'] as num?)?.toInt().clamp(1, 1000) ?? 1;
        eventQuota +=
            ((snapshot['recommended_event_quota'] as num?)?.toInt() ?? 0) *
            multiplier;
        attractionQuota +=
            ((snapshot['recommended_attraction_quota'] as num?)?.toInt() ?? 0) *
            multiplier;
      }
      if (eventQuota == 0 && attractionQuota == 0) {
        final versions = await fetchPricingVersions();
        final currentVersionName = status['pricing_version_name']?.toString();
        final currentMultiplier =
            (status['quota_multiplier'] as num?)?.toInt().clamp(1, 1000) ?? 1;
        final matchingCurrent = versions.where(
          (version) =>
              version.storagePlan == 'cloud' &&
              version.name == currentVersionName,
        );
        if (matchingCurrent.isNotEmpty) {
          eventQuota =
              (matchingCurrent.first.quotas['recommended_events'] ?? 0) *
              currentMultiplier;
          attractionQuota =
              (matchingCurrent.first.quotas['recommended_attractions'] ?? 0) *
              currentMultiplier;
        } else {
          final freeVersions =
              versions
                  .where(
                    (version) =>
                        version.storagePlan == 'cloud' &&
                        version.quarterlyPriceTwd == 0 &&
                        !version.effectiveAt.isAfter(now),
                  )
                  .toList()
                ..sort((a, b) => b.effectiveAt.compareTo(a.effectiveAt));
          if (freeVersions.isNotEmpty) {
            eventQuota = freeVersions.first.quotas['recommended_events'] ?? 0;
            attractionQuota =
                freeVersions.first.quotas['recommended_attractions'] ?? 0;
          }
        }
      }
      return [
        SubscriptionUsage(
          resource: 'recommended_events',
          used: results[0].length,
          quota: eventQuota,
        ),
        SubscriptionUsage(
          resource: 'recommended_attractions',
          used: results[1].length,
          quota: attractionQuota,
        ),
      ];
    } catch (error, stackTrace) {
      // Recommendation counters must never prevent the rest of the account
      // and subscription state from loading.
      logger.e(
        'Failed to load recommendation submission usage',
        error: error,
        stackTrace: stackTrace,
      );
      return const [];
    }
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
    try {
      final rows = await supabase.rpc(
        'admin_get_user_subscription_entitlements',
        params: {'p_email': email.trim()},
      );
      return (rows as List<dynamic>)
          .map((row) => Map<String, dynamic>.from(row as Map))
          .toList(growable: false);
    } on PostgrestException catch (error) {
      if (error.code == '42883' || error.code == 'PGRST202') return const [];
      rethrow;
    }
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

  Future<List<SubscriptionPricingVersion>> fetchPricingVersions() async {
    final rows = await supabase.rpc('get_subscription_pricing_versions');
    return (rows as List<dynamic>)
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
  }) async {
    await supabase.rpc(
      'admin_create_subscription_pricing_version',
      params: {
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
  }) async {
    await supabase.rpc(
      'admin_update_subscription_pricing_version',
      params: {
        'p_pricing_version_id': pricingVersionId,
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
      },
    );
  }

  Future<void> deletePricingVersionAsAdmin({required String versionId}) async {
    await supabase.rpc(
      'admin_delete_subscription_pricing_version',
      params: {'p_pricing_version_id': versionId},
    );
  }
}

class QuotaFreePeriod {
  const QuotaFreePeriod({
    required this.id,
    required this.name,
    required this.startsAt,
    required this.endsAt,
    required this.enabled,
    required this.isActive,
    this.reminderDays,
    this.targetAccounts = const [],
  });

  final String id;
  final String name;
  final DateTime startsAt;
  final DateTime endsAt;
  final bool enabled;
  final bool isActive;
  final int? reminderDays;
  final List<String> targetAccounts;

  factory QuotaFreePeriod.fromJson(Map<String, dynamic> json) =>
      QuotaFreePeriod(
        id: json['period_id']?.toString() ?? '',
        name: json['period_name']?.toString() ?? '',
        startsAt: DateTime.parse(json['starts_at'].toString()).toLocal(),
        endsAt: DateTime.parse(json['ends_at'].toString()).toLocal(),
        enabled: json['enabled'] == true,
        isActive: json['is_active'] == true,
        reminderDays: (json['reminder_days'] as num?)?.toInt(),
        targetAccounts: (json['target_accounts'] as List? ?? const [])
            .map((value) => value.toString().trim().toLowerCase())
            .where((value) => value.isNotEmpty)
            .toList(growable: false),
      );
}

class SubscriptionCleanupPreview {
  const SubscriptionCleanupPreview({
    required this.email,
    required this.resource,
    required this.used,
    required this.quota,
    required this.excess,
    this.graceEndsAt,
  });

  final String email;
  final String resource;
  final int used;
  final int quota;
  final int excess;
  final DateTime? graceEndsAt;

  factory SubscriptionCleanupPreview.fromJson(Map<String, dynamic> json) =>
      SubscriptionCleanupPreview(
        email: json['target_email']?.toString() ?? '',
        resource: json['resource']?.toString() ?? '',
        used: (json['used'] as num?)?.toInt() ?? 0,
        quota: (json['quota'] as num?)?.toInt() ?? 0,
        excess: (json['excess'] as num?)?.toInt() ?? 0,
        graceEndsAt: DateTime.tryParse(json['grace_ends_at']?.toString() ?? ''),
      );
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
          if (json['storage_plan']?.toString() == 'cloud') ...{
            'recommended_events':
                (json['recommended_event_quota'] as num?)?.toInt() ?? 0,
            'recommended_attractions':
                (json['recommended_attraction_quota'] as num?)?.toInt() ?? 0,
          },
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
      final value = message
          .split(quotaMarker)
          .last
          .split(RegExp(r"[\s,)]"))
          .first;
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
