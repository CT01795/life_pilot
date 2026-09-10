import 'package:idb_shim/idb_client_native.dart' hide Database;
import 'package:sembast/sembast.dart';
import 'package:sembast_web/utils/jdb.dart';

// The default sembast_web factory uses BroadcastChannel for cross-tab
// notifications. During hot reloads or when tabs run different app builds,
// those JavaScript messages can have incompatible runtime types and crash
// before the application can catch the error. Life Pilot does not require
// live cross-tab local-data synchronization, so use the same IndexedDB
// storage without the broadcast layer.
final DatabaseFactory _lifePilotWebFactory =
    DatabaseFactoryJdb(JdbFactoryIdb(idbFactoryWeb));

Future<Database> openLifePilotLocalDatabase() {
  return _lifePilotWebFactory.openDatabase('life_pilot_local');
}
