import 'package:supabase_flutter/supabase_flutter.dart';

/// Shares no completed permission decisions between accounts or storage modes.
class RepositorySubscriptionBootstrap {
  const RepositorySubscriptionBootstrap(this.client);
  final SupabaseClient client;

  Future<Map<String, dynamic>> read(String storagePlan) async {
    final result = await client.rpc(
      'get_my_subscription_bootstrap',
      params: {'p_storage_plan': storagePlan},
    );
    if (result is! Map) {
      throw const FormatException('Invalid subscription bootstrap');
    }
    return Map<String, dynamic>.from(result);
  }
}
