import 'package:life_pilot/utils/supabase.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Uses the signed-in Supabase client, never a service-role key. Only an
/// undeployed RPC may fall back; auth, quota and database errors stay visible.
class RepositoryCloudGateway {
  final SupabaseClient? _client;
  RepositoryCloudGateway({SupabaseClient? client}) : _client = client;

  Future<dynamic> rpcOrBackend(
    String function, {
    Map<String, dynamic> params = const {},
    required Future<dynamic> Function() backend,
  }) async {
    try {
      return await (_client ?? supabase).rpc(function, params: params);
    } on PostgrestException catch (error) {
      if (error.code != 'PGRST202') rethrow;
      return backend();
    }
  }
}
