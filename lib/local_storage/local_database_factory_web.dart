import 'package:sembast_web/sembast_web.dart';

Future<Database> openLifePilotLocalDatabase() {
  return databaseFactoryWeb.openDatabase('life_pilot_local');
}
