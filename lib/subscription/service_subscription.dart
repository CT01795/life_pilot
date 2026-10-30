import 'package:life_pilot/subscription/model_subscription_usage.dart';
import 'package:life_pilot/subscription/model_quota_free_period.dart';
export 'package:life_pilot/subscription/model_quota_free_period.dart';
import 'package:life_pilot/subscription/repository_subscription_counts.dart';
import 'package:life_pilot/subscription/repository_subscription_bootstrap.dart';
import 'package:life_pilot/subscription/subscription_entitlement_quota.dart';
import 'package:life_pilot/utils/supabase.dart';
import 'package:life_pilot/utils/const.dart';
import 'package:life_pilot/utils/logger.dart';
import 'package:life_pilot/utils/value_parser.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ServiceSubscription {
  static bool _supportsCumulativeQuotaRpc = true;

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

  Future<SubscriptionSnapshot> fetchMyUsage({
    String storagePlan = 'cloud',
  }) async {
    final bootstrap = await RepositorySubscriptionBootstrap(
      supabase,
    ).read(storagePlan);
    final promotionPeriods = bootstrap?['quota_free_periods'] is List
        ? List<QuotaFreePeriod>.unmodifiable(
            (bootstrap!['quota_free_periods'] as List).map(
              (row) => QuotaFreePeriod.fromJson(
                Map<String, dynamic>.from(row as Map),
              ),
            ),
          )
        : null;
    final responses = bootstrap == null
        ? await Future.wait<dynamic>([
            supabase.rpc('get_my_subscription_usage'),
            supabase.rpc('get_my_subscription_status'),
            supabase.rpc('get_my_subscription_entitlements'),
          ])
        : <dynamic>[
            bootstrap['usage'],
            [bootstrap['status']],
            bootstrap['entitlements'],
          ];
    final rows = responses.first;
    final statusRows = responses[1] as List<dynamic>;
    final entitlementRows = responses[2] as List<dynamic>;
    final status = statusRows.isEmpty
        ? <String, dynamic>{}
        : Map<String, dynamic>.from(statusRows.first as Map);
    if (status['status'] == 'configuration_missing') {
      return SubscriptionSnapshot(
        plan: 'unconfigured',
        usage: const {},
        status: 'configuration_missing',
        storagePlan: storagePlan,
        promotionPeriods: promotionPeriods,
      );
    }
    final bundledQuotas = bootstrap == null
        ? null
        : (bootstrap['cumulative_quotas'] as Map).map(
            (key, value) => MapEntry(key.toString(), parseIntValue(value)),
          );
    final recommendationUsage = bootstrap?['vendor'] == true
        ? <SubscriptionUsage>[]
        : await _fetchRecommendationUsage(
            entitlementRows,
            status,
            storagePlan: storagePlan,
            counts: (bootstrap?['recommendation_counts'] as List?)?.cast<int>(),
            resolvedQuotas: bundledQuotas,
          );
    var items = <SubscriptionUsage>[
      ...(rows as List<dynamic>).map(
        (row) =>
            SubscriptionUsage.fromJson(Map<String, dynamic>.from(row as Map)),
      ),
      ...recommendationUsage,
    ];
    // The currently selected storage location decides which entitlement set is
    // presented. Never infer it from the newest subscription row because users
    // may hold valid cloud and local subscriptions at the same time.
    final cumulativeQuotas =
        bundledQuotas ?? await _fetchCumulativeQuotas(storagePlan: storagePlan);
    if (cumulativeQuotas.isNotEmpty) {
      items = items
          .map(
            (item) =>
                cumulativeQuotas.containsKey(item.resource) &&
                    !(storagePlan == 'local' &&
                        (item.resource == 'recommended_events' ||
                            item.resource == 'recommended_attractions') &&
                        cumulativeQuotas[item.resource] == 0 &&
                        item.quota > 0)
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

  Future<Map<String, int>> _fetchCumulativeQuotas({
    required String storagePlan,
  }) async {
    if (!_supportsCumulativeQuotaRpc) return const {};
    try {
      final rows = await supabase.rpc(
        'get_my_cumulative_subscription_quotas',
        params: {'p_storage_plan': storagePlan},
      );
      return {
        for (final raw in rows as List<dynamic>)
          if (raw case final Map row)
            parseStringValue(row['resource']): parseIntValue(row['quota']),
      };
    } on PostgrestException catch (error) {
      // Older databases continue using get_my_subscription_usage until the
      // cumulative-quota RPC is installed.
      final normalizedMessage = error.message.toLowerCase();
      final isMissingRpc =
          error.code == '42883' ||
          error.code == 'PGRST202' ||
          error.code == 'PGRST205' ||
          (normalizedMessage.contains(
                'get_my_cumulative_subscription_quotas',
              ) &&
              (normalizedMessage.contains('not find') ||
                  normalizedMessage.contains('does not exist') ||
                  normalizedMessage.contains('schema cache')));
      if (isMissingRpc) {
        _supportsCumulativeQuotaRpc = false;
        logger.w(
          'Cumulative subscription quota RPC is unavailable; '
          'falling back to the existing subscription usage response.',
        );
        return const {};
      }
      rethrow;
    }
  }

  Future<List<SubscriptionUsage>> _fetchRecommendationUsage(
    List<dynamic> entitlementRows,
    Map<String, dynamic> status, {
    required String storagePlan,
    List<int>? counts,
    Map<String, int>? resolvedQuotas,
  }) async {
    try {
      final account = supabase.auth.currentUser?.email?.toLowerCase();
      if (account == null || account.isEmpty) return const [];
      final now = DateTime.now();
      final results =
          counts ??
          await RepositorySubscriptionCounts(
            supabase,
          ).readRecommendations(account: account, now: now);
      if (storagePlan == 'cloud' &&
          resolvedQuotas?.containsKey('recommended_events') == true &&
          resolvedQuotas?.containsKey('recommended_attractions') == true) {
        return [
          SubscriptionUsage(
            resource: 'recommended_events',
            used: results[0],
            quota: resolvedQuotas!['recommended_events']!,
          ),
          SubscriptionUsage(
            resource: 'recommended_attractions',
            used: results[1],
            quota: resolvedQuotas['recommended_attractions']!,
          ),
        ];
      }

      var eventQuota = 0;
      var attractionQuota = 0;
      final activeEntitlements = entitlementRows
          .where((raw) {
            final row = Map<String, dynamic>.from(raw as Map);
            final endsAt = tryParseDateTimeValue(row['ends_at']);
            return parseStringValue(row['storage_plan']) == storagePlan &&
                endsAt != null &&
                endsAt.isAfter(now);
          })
          .toList(growable: false);
      for (final raw in activeEntitlements) {
        final row = Map<String, dynamic>.from(raw as Map);
        final snapshot = Map<String, dynamic>.from(
          row['entitlement_snapshot'] as Map? ?? const {},
        );
        final multiplier = parseIntValue(
          row['quota_multiplier'],
          fallback: 1,
        ).clamp(1, 1000).toInt();
        eventQuota +=
            entitlementSnapshotQuota(
              snapshot,
              'recommended_events',
              multiplier: multiplier,
            ) ??
            0;
        attractionQuota +=
            entitlementSnapshotQuota(
              snapshot,
              'recommended_attractions',
              multiplier: multiplier,
            ) ??
            0;
      }
      if (eventQuota == 0 && attractionQuota == 0) {
        final versions = await fetchPricingVersions();
        final currentVersionName = parseStringValue(
          status['pricing_version_name'],
        );
        final currentMultiplier = parseIntValue(
          status['quota_multiplier'],
          fallback: 1,
        ).clamp(1, 1000).toInt();
        final statusPeriodEnd = tryParseDateTimeValue(
          status['current_period_end'],
        );
        final hasActiveStatusPlan =
            parseStringValue(status['plan']) == 'plus' &&
            parseStringValue(status['storage_plan']) == storagePlan &&
            (statusPeriodEnd == null || statusPeriodEnd.isAfter(now));
        final hasActivePaidPlan =
            activeEntitlements.isNotEmpty || hasActiveStatusPlan;
        final matchingCurrent = versions.where(
          (version) =>
              version.storagePlan == storagePlan &&
              version.name == currentVersionName,
        );
        if (hasActivePaidPlan && matchingCurrent.isNotEmpty) {
          eventQuota =
              (matchingCurrent.first.quotas['recommended_events'] ?? 0) *
              currentMultiplier;
          attractionQuota =
              (matchingCurrent.first.quotas['recommended_attractions'] ?? 0) *
              currentMultiplier;
        }

        // 本機資料本身不限量，但推薦活動／景點仍是公開雲端投稿，
        // 因此有效本機訂閱沿用當期免費雲端版本的投稿上限。
        // 本機訂閱失效後不套用此 fallback，兩項額度維持 0。
        if (storagePlan == 'local' &&
            hasActivePaidPlan &&
            eventQuota == 0 &&
            attractionQuota == 0) {
          final publicVersions =
              versions
                  .where(
                    (version) =>
                        version.storagePlan == 'cloud' &&
                        version.quarterlyPriceTwd == 0 &&
                        !version.effectiveAt.isAfter(now),
                  )
                  .toList()
                ..sort((a, b) => b.effectiveAt.compareTo(a.effectiveAt));
          if (publicVersions.isNotEmpty) {
            final entitlementMultiplier = activeEntitlements.isEmpty
                ? currentMultiplier
                : activeEntitlements.fold<int>(
                    0,
                    (total, raw) =>
                        total +
                        parseIntValue(
                          Map<String, dynamic>.from(
                            raw as Map,
                          )['quota_multiplier'],
                          fallback: 1,
                        ).clamp(1, 1000).toInt(),
                  );
            eventQuota =
                (publicVersions.first.quotas['recommended_events'] ?? 0) *
                entitlementMultiplier;
            attractionQuota =
                (publicVersions.first.quotas['recommended_attractions'] ?? 0) *
                entitlementMultiplier;
          }
        } else if (storagePlan == 'cloud' && !hasActivePaidPlan) {
          final freeVersions =
              versions
                  .where(
                    (version) =>
                        version.storagePlan == storagePlan &&
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
          used: results[0],
          quota: eventQuota,
        ),
        SubscriptionUsage(
          resource: 'recommended_attractions',
          used: results[1],
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
        'p_recommended_event_quota': quotas['event'],
        'p_recommended_attraction_quota': quotas['attraction'],
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
        email: parseStringValue(json['target_email']),
        resource: parseStringValue(json['resource']),
        used: parseIntValue(json['used']),
        quota: parseIntValue(json['quota']),
        excess: parseIntValue(json['excess']),
        graceEndsAt: tryParseDateTimeValue(json['grace_ends_at']),
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
        id: parseStringValue(json[Fields.id]),
        name: parseStringValue(json['version_name']),
        storagePlan: parseStringValue(json['storage_plan'], fallback: 'cloud'),
        effectiveAt:
            tryParseDateTimeValue(json['effective_at']) ?? DateTime.now(),
        quarterlyPriceTwd: parseIntValue(json['quarterly_price_twd']),
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
