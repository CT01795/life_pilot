import 'package:life_pilot/utils/supabase.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Calls Supabase with the signed-in client and propagates database errors.
class RepositoryCloudGateway {
  final SupabaseClient? _client;
  RepositoryCloudGateway({SupabaseClient? client}) : _client = client;

  Future<dynamic> rpc(
    String function, {
    Map<String, dynamic> params = const {},
  }) async => await (_client ?? supabase).rpc(function, params: params);
}
