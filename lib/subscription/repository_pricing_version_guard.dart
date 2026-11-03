import 'package:life_pilot/utils/supabase.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Admin-only preflight, called on edit/delete intent, never once per list row.
/// The database trigger remains authoritative if usage changes after this read.
class RepositoryPricingVersionGuard {
  Future<bool> canForceDelete(String id, {bool vendor = false}) async {
    try {
      final result = await supabase.rpc(
        'admin_can_force_delete_pricing_version',
        params: {'p_version_id': id, 'p_vendor': vendor},
      );
      if (result is! bool) {
        throw const FormatException('Invalid pricing history');
      }
      return result;
    } on PostgrestException catch (error) {
      if (error.code == 'PGRST202') return false;
      rethrow;
    }
  }

  Future<bool> isLocked(String id, {bool vendor = false}) async {
    final result = await supabase.rpc(
      'admin_pricing_version_is_locked',
      params: {'p_version_id': id, 'p_vendor': vendor},
    );
    if (result is! bool) throw const FormatException('Invalid pricing lock');
    return result;
  }
}
