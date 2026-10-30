import 'package:supabase_flutter/supabase_flutter.dart';

/// Only a genuinely undeployed function enables a legacy fallback. Never cache
/// user data or convert authorization/database failures into another endpoint.
class RepositoryOptionalJsonRpc {
  const RepositoryOptionalJsonRpc(this.client);
  final SupabaseClient client;
  static final _missing = Expando<Set<String>>();

  Future<Map<String, dynamic>?> read(
    String function, {
    Map<String, dynamic> params = const {},
  }) async {
    if (_missing[client]?.contains(function) == true) return null;
    try {
      final result = await client.rpc(function, params: params);
      if (result is! Map) {
        throw FormatException('Invalid response for $function');
      }
      return Map<String, dynamic>.from(result);
    } on PostgrestException catch (error) {
      if (error.code != 'PGRST202') rethrow;
      (_missing[client] ??= <String>{}).add(function);
      return null;
    }
  }
}
