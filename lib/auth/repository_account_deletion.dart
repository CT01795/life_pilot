import 'package:life_pilot/utils/repository_session_reads.dart';
import 'package:life_pilot/utils/service/service_cloud_api.dart';
import 'package:life_pilot/utils/supabase.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:life_pilot/auth/model_account_deletion_page.dart';

/// Account deletion is an authenticated server workflow, separate from Excel.
/// Writes never share a Future or retry automatically: the outcome may be final.
class RepositoryAccountDeletion {
  RepositoryAccountDeletion({SupabaseClient? client})
    : client = client ?? supabase;
  final SupabaseClient client;
  static const _group = 'account-deletion';

  Future<AccountDeletionPage> adminPage({AccountDeletionCursor? after}) {
    return RepositorySessionReads(client).read(
      _group,
      ('page', after?.status, after?.at?.toUtc().toIso8601String(), after?.id),
      () async {
        final result = await client.rpc(
          'admin_list_account_deletion_requests_page',
          params: {
            'p_after': after?.toJson(),
            'p_limit': AccountDeletionPage.size,
          },
        );
        if (result is! Map || result['rows'] is! List) {
          throw const FormatException('Invalid deletion page');
        }
        return AccountDeletionPage.fromRows(result['rows'] as List);
      },
    );
  }

  Future<Map<String, dynamic>?> ownRequest() =>
      RepositorySessionReads(client).read(_group, 'own', () async {
        final rows =
            await client.rpc('get_my_account_deletion_request') as List;
        return rows.isEmpty
            ? null
            : Map<String, dynamic>.unmodifiable(rows.first as Map);
      });

  Future<void> request() => _mutate('request_account_deletion');
  Future<void> cancel() => _mutate('cancel_account_deletion_request');
  Future<void> approve(String id) => _purge(id);
  Future<void> disable(String id) =>
      _mutate('admin_disable_account_for_deletion', {'p_request_id': id});
  Future<void> deleteDisabled(String id) => _purge(id);
  Future<void> reactivate(String id) =>
      _mutate('admin_reactivate_disabled_account', {'p_request_id': id});

  Future<void> _purge(String id) async {
    final reads = RepositorySessionReads(client);
    reads.invalidate(_group);
    try {
      final response = await ServiceCloudApi(
        client: client,
      ).post('/account/admin/purge-account', {'request_id': id});
      if (response is Map && response['completed'] == true) return;
      if (response is Map && response['completed'] == false) {
        throw StateError('account_storage_purge_more_files');
      }
      throw const FormatException('Invalid account purge response');
    } finally {
      reads.invalidate(_group);
    }
  }

  Future<AccountDeletionPage> disabledPage({required int offset}) async {
    final rows =
        await client.rpc(
              'admin_list_disabled_accounts',
              params: {'p_offset': offset},
            )
            as List;
    return AccountDeletionPage.fromRows([
      for (final row in rows)
        {
          'id': row['id'],
          'email': row['email'],
          'status': 'pending',
          'requested_at': row['disabled_at'],
        },
    ], offsetBased: true);
  }

  Future<void> confirmCancellation(String id) => _mutate(
    'admin_confirm_account_deletion_cancellation',
    {'p_request_id': id},
  );

  Future<void> _mutate(
    String function, [
    Map<String, dynamic> params = const {},
  ]) async {
    final reads = RepositorySessionReads(client);
    reads.invalidate(_group);
    try {
      await client.rpc(function, params: params);
    } finally {
      reads.invalidate(_group);
    }
  }
}
