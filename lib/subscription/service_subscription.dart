import 'package:life_pilot/subscription/model_subscription_usage.dart';
import 'package:life_pilot/utils/api.dart';

class ServiceSubscription {
  Future<SubscriptionSnapshot> fetchMyUsage() async {
    final responses = await Future.wait([
      supabase.rpc('get_my_subscription_usage'),
      supabase.rpc('get_my_subscription_status'),
    ]);
    final rows = responses.first;
    final statusRows = responses.last as List<dynamic>;
    final status = statusRows.isEmpty
        ? <String, dynamic>{}
        : Map<String, dynamic>.from(statusRows.first as Map);
    final items = (rows as List<dynamic>)
        .map((row) => SubscriptionUsage.fromJson(
              Map<String, dynamic>.from(row as Map),
            ))
        .toList();
    final plan = items.isEmpty
        ? 'free'
        : (rows.first as Map)['plan']?.toString() ?? 'free';
    return SubscriptionSnapshot(
      plan: plan,
      usage: {for (final item in items) item.resource: item},
      status: status['status']?.toString() ?? 'inactive',
      currentPeriodEnd: DateTime.tryParse(
        status['current_period_end']?.toString() ?? '',
      ),
      cancelAtPeriodEnd: status['cancel_at_period_end'] == true,
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
