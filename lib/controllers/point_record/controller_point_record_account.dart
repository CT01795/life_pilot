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
  bool isLoading = false;
  bool isLoaded = false;

  Future<void> loadAccounts() async {
    isLoading = true;
    notifyListeners();
    accounts = await service.fetchAccounts(
      user: auth?.currentAccount?? constEmpty,
    );
    isLoading = false;
    isLoaded = true;
    notifyListeners();
  }

  Future<void> createAccount(String name) async {
    await service.createAccount(
      name: name,
      user: auth?.currentAccount?? constEmpty,
    );
    // ⭐ 統一來源：重新拉一次
    await loadAccounts();
  }

  Future<void> deleteAccount(String accountId) async {
    await service.deleteAccount(accountId: accountId);
    accounts.removeWhere((a) => a.id == accountId);
    notifyListeners();
  }

  Future<void> updateAccountImage(String accountId, XFile pickedFile) async {
    Uint8List bytes = await pickedFile.readAsBytes(); // Web / 手機都可以

    // 上傳圖片給後端，後端返回可訪問 URL
    final newImage = await service.uploadAccountImageBytesDirect(accountId, bytes);

    final index = accounts.indexWhere((a) => a.id == accountId);
    if (index == -1) return;

    accounts[index] = accounts[index].copyWith(
      masterGraphUrl: newImage,
    );

    notifyListeners();
  }

  ModelPointRecordAccount getAccountById(String id) =>
      accounts.firstWhere(
        (a) => a.id == id
      );

  void updateAccountTotals({
    required String accountId,
    required int deltaPoints,
    required int deltaBalance,
  }) {
    final index = accounts.indexWhere((a) => a.id == accountId);
    if (index == -1) return;

    final old = accounts[index];
    accounts[index] = old.copyWith(
      points: old.points + deltaPoints,
      balance: old.balance + deltaBalance,
    );

    notifyListeners();
  }
}
