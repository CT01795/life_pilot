import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:life_pilot/utils/repository_optional_json_rpc.dart';

/// Shares no completed permission decisions between accounts or storage modes.
class RepositorySubscriptionBootstrap {
  const RepositorySubscriptionBootstrap(this.client);
  final SupabaseClient client;

  Future<Map<String, dynamic>?> read(String storagePlan) =>
      RepositoryOptionalJsonRpc(client).read(
        'get_my_subscription_bootstrap',
        params: {'p_storage_plan': storagePlan},
      );
}
