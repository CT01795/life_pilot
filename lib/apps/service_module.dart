import 'package:life_pilot/utils/supabase.dart';
import 'package:life_pilot/utils/value_parser.dart';
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

      return (response as List)
          .map((e) => parseStringValue(e['module_key']))
          .toList();
    } catch (e, st) {
      logger.e('loadModulesFromServer failed $e\n$st');
      rethrow;
    }
  }

  Future<List<String>> loadUserModulesAsAdmin(String account) async {
    final response = await supabase.rpc(
      'admin_get_user_modules',
      params: {'p_email': normalizeText(account)},
    );
    return (response as List)
        .map((row) => parseOptionalStringValue((row as Map)['module_key']))
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
