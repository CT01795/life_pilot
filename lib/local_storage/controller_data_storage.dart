import 'package:flutter/foundation.dart';
import 'package:life_pilot/local_storage/local_data_store.dart';

class ControllerDataStorage extends ChangeNotifier {
  ControllerDataStorage(this.account);

  final String account;
  DataStorageLocation _location = DataStorageLocation.cloud;
  bool _loaded = false;

  DataStorageLocation get location => _location;
  bool get isLocal => _location == DataStorageLocation.local;
  bool get loaded => _loaded;

  Future<void> load() async {
    _location = await LocalDataStore.instance.preferredLocation(account) ??
        DataStorageLocation.cloud;
    _loaded = true;
    notifyListeners();
  }

  Future<void> setLocation(DataStorageLocation location) async {
    if (_location == location && _loaded) return;
    await LocalDataStore.instance.setPreferredLocation(account, location);
    _location = location;
    _loaded = true;
    notifyListeners();
  }
}
