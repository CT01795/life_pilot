import 'package:life_pilot/utils/api.dart';
import 'package:life_pilot/utils/const.dart';
import 'package:life_pilot/utils/logger.dart';
import 'package:life_pilot/utils/text_normalization.dart';

class ServiceModule {
  ServiceModule();

  Future<List<String>> loadModulesFromServer(String account) async {
    try {
      final now = DateTime.now().toUtc().toIso8601String();
      final normalizedAccount = normalizeText(account);

      final response = await supabase
          .from(TableNames.userModule)
          .select('module_key')
          .eq(Fields.account, normalizedAccount)
          .eq('enabled', true)
          .or('stop_at.is.null,stop_at.gt.$now');

      return (response as List).map((e) => e['module_key'].toString()).toList();
    } catch (e, st) {
      logger.e('loadModulesFromServer failed $e\n$st');
      return [];
    }
  }

  Future<List<String>> loadUserModulesAsAdmin(String account) async {
    final response = await supabase.rpc(
      'admin_get_user_modules',
      params: {'p_email': normalizeText(account)},
    );
    return (response as List)
        .map((row) => (row as Map)['module_key']?.toString())
        .whereType<String>()
        .toList(growable: false);
  }

  Future<void> saveUserModulesAsAdmin({
    required String account,
    required Iterable<String> moduleKeys,
  }) async {
    await supabase.rpc(
      'admin_set_user_modules',
      params: {
        'p_email': normalizeText(account),
        'p_module_keys': moduleKeys.toList(growable: false),
      },
    );
  }
}
