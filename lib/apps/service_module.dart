import 'package:life_pilot/utils/api.dart';
import 'package:life_pilot/utils/const.dart';
import 'package:life_pilot/utils/logger.dart';

class ServiceModule {
  ServiceModule();

  Future<List<String>> loadModulesFromServer(String account) async {
    try {
      final response =
          await apiSupabase.post('module/load_modules_from_server', {
        "table_name": TableNames.userModule,
        "account": account,
      });

      if (response == null) return [];

      final list = (response as List).map((e) => e.toString()).toList();

      return list;
    } on Exception catch (exception) {
      logger.e(exception);
      return [];
    }
  }
}
