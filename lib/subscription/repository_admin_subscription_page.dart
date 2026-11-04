import 'package:life_pilot/subscription/model_admin_subscription_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RepositoryAdminSubscriptionPage {
  const RepositoryAdminSubscriptionPage(this.client);
  final SupabaseClient client;
  Future<AdminSubscriptionPage> read({
    AdminSubscriptionCursor? after,
    int offset = 0,
    bool legacy = false,
  }) async {
    if (offset < 0) throw ArgumentError.value(offset, 'offset');
    final token = client.auth.currentSession?.accessToken,
        owner = client.auth.currentUser?.id;
    if (token == null || owner == null) {
      throw StateError('Authentication required');
    }
    void checkOwner() {
      if (client.auth.currentUser?.id != owner ||
          client.auth.currentSession?.accessToken != token) {
        throw StateError('Subscription list account changed');
      }
    }

    final result = await client
        .rpc(
          'admin_list_user_subscription_summaries_page',
          params: {
            'p_after_email': after?.email,
            'p_after_user_id': after?.userId,
            'p_limit': AdminSubscriptionPage.size,
          },
        )
        .timeout(const Duration(seconds: 30));
    checkOwner();
    if (result is! Map || result['rows'] is! List) {
      throw const FormatException('Invalid subscription page');
    }
    return AdminSubscriptionPage.fromRows(result['rows'] as List);
  }
}
