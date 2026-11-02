import 'package:life_pilot/subscription/model_admin_subscription_overview.dart';
import 'package:life_pilot/utils/repository_optional_json_rpc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// One round trip for a lookup; no completed permission/subscription cache.
class RepositoryAdminSubscriptionOverview {
  const RepositoryAdminSubscriptionOverview(this.client);
  final SupabaseClient client;

  Future<AdminSubscriptionOverview> read(String email) async {
    final owner = client.auth.currentUser?.id,
        token = client.auth.currentSession?.accessToken;
    if (owner == null || token == null) {
      throw StateError('Authentication required');
    }
    final params = {'p_email': email.trim().toLowerCase()};
    var result = await RepositoryOptionalJsonRpc(client)
        .read(
          'admin_get_user_subscription_overview',
          params: params,
          rememberMissing: false,
        )
        .timeout(const Duration(seconds: 30));
    void checkOwner() {
      if (client.auth.currentUser?.id != owner ||
          client.auth.currentSession?.accessToken != token) {
        throw StateError('Subscription lookup account changed');
      }
    }

    checkOwner();
    if (result == null) {
      final rows = await Future.wait([
        client.rpc('admin_get_user_subscription', params: params),
        client.rpc('admin_get_user_subscription_entitlements', params: params),
      ]).timeout(const Duration(seconds: 30));
      checkOwner();
      final subscriptions = rows[0] as List;
      result = {
        'subscription': subscriptions.isEmpty ? null : subscriptions.first,
        'entitlements': rows[1],
      };
    }
    return AdminSubscriptionOverview.fromJson(result);
  }
}
