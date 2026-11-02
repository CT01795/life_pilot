import 'package:life_pilot/subscription/model_quota_free_period.dart';
import 'package:life_pilot/subscription/model_subscription_cleanup_preview.dart';
import 'package:life_pilot/utils/repository_session_reads.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Shares only currently running reads, not completed permission/quota results.
/// Mutations are never coalesced or retried automatically.
class RepositorySubscriptionMaintenance {
  const RepositorySubscriptionMaintenance(this.client);
  final SupabaseClient client;
  static const _periods = 'quota-free-periods';
  static const _cleanup = 'subscription-cleanup';

  Future<List<QuotaFreePeriod>> periods() =>
      RepositorySessionReads(client).read(_periods, 'list', () async {
        final rows = await client.rpc('get_quota_free_period');
        if (rows is! List) {
          throw const FormatException('Invalid promotion periods');
        }
        return List.unmodifiable(
          rows.map(
            (row) =>
                QuotaFreePeriod.fromJson(Map<String, dynamic>.from(row as Map)),
          ),
        );
      });

  Future<void> savePeriod(Map<String, dynamic> params) =>
      _mutate(_periods, 'admin_set_quota_free_period', params);
  Future<void> deletePeriod(String id) =>
      _mutate(_periods, 'admin_delete_quota_free_period', {'p_period_id': id});

  Future<List<SubscriptionCleanupPreview>> preview(String? email) =>
      RepositorySessionReads(client).read(
        _cleanup,
        ('preview', email?.trim()),
        () async {
          final rows = await client.rpc(
            'get_subscription_cleanup_preview',
            params: {'p_email': email?.trim()},
          );
          if (rows is! List) {
            throw const FormatException('Invalid cleanup preview');
          }
          return List.unmodifiable(
            rows.map(
              (row) => SubscriptionCleanupPreview.fromJson(
                Map<String, dynamic>.from(row as Map),
              ),
            ),
          );
        },
      );

  Future<Map<String, dynamic>> cleanup(String? email, String mode) async {
    final reads = RepositorySessionReads(client);
    reads.invalidate(_cleanup);
    try {
      final result = await client.rpc(
        'cleanup_subscription_data',
        params: {'p_email': email?.trim(), 'p_mode': mode},
      );
      return Map<String, dynamic>.from(result as Map);
    } finally {
      reads.invalidate(_cleanup);
    }
  }

  Future<void> _mutate(
    String group,
    String function,
    Map<String, dynamic> params,
  ) async {
    final reads = RepositorySessionReads(client);
    reads.invalidate(group);
    // Promotion changes can alter the limits shown by an in-flight preview.
    reads.invalidate(_cleanup);
    try {
      await client.rpc(function, params: params);
    } finally {
      reads.invalidate(group);
      reads.invalidate(_cleanup);
    }
  }
}
