import 'package:life_pilot/utils/supabase.dart';

/// Admin-only preflight, called on edit/delete intent, never once per list row.
/// The database trigger remains authoritative if usage changes after this read.
class RepositoryPricingVersionGuard {
  Future<bool> isLocked(String id, {bool vendor = false}) async {
    final result = await supabase.rpc(
      'admin_pricing_version_is_locked',
      params: {'p_version_id': id, 'p_vendor': vendor},
    );
    if (result is! bool) throw const FormatException('Invalid pricing lock');
    return result;
  }
}
