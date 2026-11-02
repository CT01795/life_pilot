import 'package:life_pilot/utils/supabase.dart';
import 'package:life_pilot/utils/value_parser.dart';
import 'package:life_pilot/utils/const.dart';
import 'package:life_pilot/utils/logger.dart';
import 'package:life_pilot/utils/text_normalization.dart';
import 'package:life_pilot/utils/repository_session_reads.dart';

class ServiceModule {
  ServiceModule();

  Future<List<String>> loadModulesFromServer(String account) =>
      RepositorySessionReads(supabase).read('modules', (
        'own',
        normalizeText(account),
      ), () => _loadModulesFromServer(account));

  Future<List<String>> _loadModulesFromServer(String account) async {
    try {
      final now = DateTime.now().toUtc().toIso8601String();
      final normalizedAccount = normalizeText(account);

      final response = await supabase
          .from(TableNames.userModule)
          .select('module_key')
          .eq(Fields.account, normalizedAccount)
          .eq('enabled', true)
          .or('stop_at.is.null,stop_at.gt.$now');

      return List<String>.unmodifiable(
        (response as List)
            .map((e) => parseStringValue(e['module_key']))
            .toList(growable: false),
      );
    } catch (e, st) {
      logger.e('loadModulesFromServer failed $e\n$st');
      rethrow;
    }
  }

  Future<List<String>> loadUserModulesAsAdmin(String account) async {
    return RepositorySessionReads(supabase).read('modules', (
      'admin',
      normalizeText(account),
    ), () => _loadUserModulesAsAdmin(account));
  }

  Future<List<String>> _loadUserModulesAsAdmin(String account) async {
    final response = await supabase.rpc(
      'admin_get_user_modules',
      params: {'p_email': normalizeText(account)},
    );
    return List<String>.unmodifiable(
      (response as List)
          .map((row) => parseOptionalStringValue((row as Map)['module_key']))
          .whereType<String>()
          .toList(growable: false),
    );
  }

  Future<void> saveUserModulesAsAdmin({
    required String account,
    required Iterable<String> moduleKeys,
  }) async {
    final client = supabase;
    final reads = RepositorySessionReads(client);
    reads.invalidate('modules');
    try {
      await client.rpc(
        'admin_set_user_modules',
        params: {
          'p_email': normalizeText(account),
          'p_module_keys': moduleKeys.toList(growable: false),
        },
      );
    } finally {
      reads.invalidate('modules');
    }
  }
}
