import 'package:life_pilot/local_storage/local_data_store.dart'
    show DataStorageLocation;
import 'package:life_pilot/utils/text_normalization.dart';

/// Value identity for personal reads and controller state, not a permission
/// check. Keep account, device/cloud mode and cleanup revision independent of
/// UI, authentication services and serialized string delimiters.
final class ModelPersonalDataScope {
  ModelPersonalDataScope({String? account, this.storage, this.revision = 0})
    : account = normalizeText(account);

  final String account;
  final DataStorageLocation? storage;
  final int revision;

  @override
  bool operator ==(Object other) =>
      other is ModelPersonalDataScope &&
      account == other.account &&
      storage == other.storage &&
      revision == other.revision;

  @override
  int get hashCode => Object.hash(account, storage, revision);
}
