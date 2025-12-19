import 'package:flutter/foundation.dart';
import 'package:life_pilot/controllers/auth/controller_auth.dart';
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
      userId: auth!.currentAccount!,
    );
    notifyListeners();
  }

  Future<void> createAccount(String name) async {
    await service.createAccount(
      name: name,
      userId: auth!.currentAccount!,
    );
    await loadAccounts();
  }

  Future<void> deleteAccount(String accountId) async {
    await service.deleteAccount(accountId: accountId);
    await loadAccounts();
  }
  
  ModelPointRecordAccount getAccountById(String id) =>
      accounts.firstWhere((a) => a.id == id);
}