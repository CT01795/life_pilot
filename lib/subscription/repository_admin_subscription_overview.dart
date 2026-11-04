import 'package:life_pilot/subscription/model_admin_subscription_overview.dart';
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
    final result = await client
        .rpc('admin_get_user_subscription_overview', params: params)
        .timeout(const Duration(seconds: 30));
    void checkOwner() {
      if (client.auth.currentUser?.id != owner ||
          client.auth.currentSession?.accessToken != token) {
        throw StateError('Subscription lookup account changed');
      }
    }

    checkOwner();
    if (result is! Map) {
      throw const FormatException('Invalid subscription overview');
    }
    return AdminSubscriptionOverview.fromJson(
      Map<String, dynamic>.from(result),
    );
  }
}
