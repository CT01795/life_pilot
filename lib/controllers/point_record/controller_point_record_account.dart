import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:life_pilot/controllers/auth/controller_auth.dart';
import 'package:life_pilot/core/const.dart';
import 'package:life_pilot/models/point_record/model_point_record_account.dart';
import 'package:life_pilot/services/service_point_record.dart';

class ControllerPointRecordAccount extends ChangeNotifier {
  final ServicePointRecord service;
  ControllerAuth? auth;

  ControllerPointRecordAccount({
    required this.service,
    required this.auth,
  });

  List<ModelPointRecordAccount> accounts = [];

  Future<void> loadAccounts() async {
    accounts = await service.fetchAccounts(
      user: auth?.currentAccount?? constEmpty,
    );
    notifyListeners();
  }

  Future<void> createAccount(String name) async {
    await service.createAccount(
      name: name,
      user: auth?.currentAccount?? constEmpty,
    );
    await loadAccounts();
  }

  Future<void> deleteAccount(String accountId) async {
    await service.deleteAccount(accountId: accountId);
    await loadAccounts();
  }

  Future<void> updateAccountImage(String accountId, XFile pickedFile) async {
    Uint8List bytes = await pickedFile.readAsBytes(); // Web / 手機都可以

    // 上傳圖片給後端，後端返回可訪問 URL
    await service.uploadAccountImageBytesDirect(accountId, bytes);

    // 重新抓最新帳號資料
    await loadAccounts(); // 這會刷新 accounts list 並通知 UI
  }

  ModelPointRecordAccount getAccountById(String id) =>
      accounts.firstWhere((a) => a.id == id);
}