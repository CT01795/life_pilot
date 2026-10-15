import 'package:life_pilot/apps/service_module.dart';
import 'package:life_pilot/utils/logger.dart';
import 'package:life_pilot/utils/safe_change_notifier.dart';
import 'package:life_pilot/utils/text_normalization.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

enum ModuleAuthorizationResult {
  loaded,
  saved,
  searchFirst,
  userNotFound,
  notDeployed,
  loadFailed,
  saveFailed,
}

/// Binds editable permissions to the account that was successfully looked up.
class ControllerModuleAuthorization extends SafeChangeNotifier {
  ControllerModuleAuthorization({required ServiceModule service})
    : _service = service;

  final ServiceModule _service;
  String _inputEmail = '';
  String? _loadedEmail;
  final Set<String> _selectedKeys = {};
  bool _loading = false;
  int _generation = 0;

  bool get isLoading => _loading;
  bool get hasSearched => _loadedEmail != null && _loadedEmail == _inputEmail;
  Set<String> get selectedKeys => Set.unmodifiable(_selectedKeys);

  void setEmail(String value) {
    final normalized = normalizeText(value);
    if (notifierDisposed || normalized == _inputEmail) return;
    _inputEmail = normalized;
    _loadedEmail = null;
    _selectedKeys.clear();
    _generation++;
    _loading = false;
    notifyListeners();
  }

  void setSelected(String key, bool selected) {
    if (notifierDisposed || _loading || !hasSearched) return;
    final changed = selected
        ? _selectedKeys.add(key)
        : _selectedKeys.remove(key);
    if (changed) notifyListeners();
  }

  bool _isCurrent(int generation) =>
      !notifierDisposed && generation == _generation;

  Future<ModuleAuthorizationResult?> search(String email) async {
    if (notifierDisposed || _loading) return null;
    setEmail(email);
    if (_inputEmail.isEmpty) return ModuleAuthorizationResult.searchFirst;
    final account = _inputEmail;
    final generation = ++_generation;
    _loading = true;
    _loadedEmail = null;
    _selectedKeys.clear();
    notifyListeners();
    try {
      final keys = await _service.loadUserModulesAsAdmin(account);
      if (!_isCurrent(generation)) return null;
      _selectedKeys.addAll(keys);
      _loadedEmail = account;
      return ModuleAuthorizationResult.loaded;
    } catch (error, stackTrace) {
      if (!_isCurrent(generation)) return null;
      logger.e(
        'Failed to load module authorization',
        error: error,
        stackTrace: stackTrace,
      );
      return _failure(error, saving: false);
    } finally {
      if (_isCurrent(generation)) {
        _loading = false;
        notifyListeners();
      }
    }
  }

  Future<ModuleAuthorizationResult?> save() async {
    if (notifierDisposed || _loading) return null;
    if (!hasSearched) return ModuleAuthorizationResult.searchFirst;
    final account = _loadedEmail!;
    final selected = Set<String>.of(_selectedKeys);
    final generation = ++_generation;
    _loading = true;
    notifyListeners();
    try {
      await _service.saveUserModulesAsAdmin(
        account: account,
        moduleKeys: selected,
      );
      if (!_isCurrent(generation)) return null;
      final saved = (await _service.loadUserModulesAsAdmin(account)).toSet();
      if (!_isCurrent(generation)) return null;
      if (saved.length != selected.length || !saved.containsAll(selected)) {
        return ModuleAuthorizationResult.saveFailed;
      }
      _selectedKeys
        ..clear()
        ..addAll(saved);
      return ModuleAuthorizationResult.saved;
    } catch (error, stackTrace) {
      if (!_isCurrent(generation)) return null;
      logger.e(
        'Failed to save module authorization',
        error: error,
        stackTrace: stackTrace,
      );
      return _failure(error, saving: true);
    } finally {
      if (_isCurrent(generation)) {
        _loading = false;
        notifyListeners();
      }
    }
  }

  ModuleAuthorizationResult _failure(Object error, {required bool saving}) {
    if (error case PostgrestException(:final code)) {
      if (code == 'PGRST202' || code == '42883') {
        return ModuleAuthorizationResult.notDeployed;
      }
      if (code == 'P0002') return ModuleAuthorizationResult.userNotFound;
    }
    return saving
        ? ModuleAuthorizationResult.saveFailed
        : ModuleAuthorizationResult.loadFailed;
  }
}
