import 'package:life_pilot/local_storage/local_data_store.dart';
import 'package:life_pilot/utils/const.dart';
import 'package:life_pilot/utils/record_row_utils.dart';
import 'package:life_pilot/utils/value_parser.dart';

/// Resolves event-linked local accounts without UI or authentication state.
/// Prefer a direct account ID; otherwise use the latest linked detail only.
class RepositoryLocalEventAccount {
  final LocalDataStore _store;
  RepositoryLocalEventAccount({LocalDataStore? store})
    : _store = store ?? LocalDataStore.instance;

  Future<Map<String, dynamic>?> find({
    required String owner,
    required String eventId,
    required String accountResource,
    required String detailResource,
  }) async {
    final direct = await _store.readOnlyRow(
      owner: owner,
      resource: accountResource,
      id: eventId,
    );
    bool valid(Map<String, dynamic>? row, String id) =>
        row != null &&
        row[Fields.isValid] == true &&
        parseStringValue(row[Fields.id]) == id;
    if (valid(direct, eventId)) return direct;

    final details = await _store.readOnlyRows(
      owner: owner,
      resource: detailResource,
    );
    final accountId = parseOptionalStringValue(
      latestRecordRowForEvent(details, eventId)?['account_id'],
    );
    if (accountId == null) return null;
    final linked = await _store.readOnlyRow(
      owner: owner,
      resource: accountResource,
      id: accountId,
    );
    return valid(linked, accountId) ? linked : null;
  }
}
