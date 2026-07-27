import 'package:life_pilot/utils/const.dart';
import 'package:life_pilot/utils/logger.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ServiceModule {
  final SupabaseClient _supabase = Supabase.instance.client;
  ServiceModule();

  Future<List<String>> loadModulesFromServer(String account) async {
    try {
      final now = DateTime.now().toUtc().toIso8601String();

      final response = await _supabase
          .from(TableNames.userModule)
          .select('module_key')
          .eq('account', account)
          .or('stop_at.is.null,stop_at.gt.$now');

      return (response as List)
          .map((e) => e['module_key'].toString())
          .toList();

    } catch (e, st) {
      logger.e('loadModulesFromServer failed $e\n$st');
      return [];
    }
  }
}
