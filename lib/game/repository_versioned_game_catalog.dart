import 'package:life_pilot/local_storage/local_data_store.dart';
import 'package:life_pilot/utils/value_parser.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

typedef VersionedGameCatalog = ({
  String version,
  List<Map<String, dynamic>> rows,
});

/// Store the version and complete catalog in one row so a partial write
/// cannot advertise a current version.
class RepositoryVersionedGameCatalog {
  const RepositoryVersionedGameCatalog(this.store);
  final LocalDataStore store;
  static const _resource = 'local_game_catalog_snapshot';
  static const _id = 'catalog';
  static final _latest = Expando<Map<String, Object>>();
  static final _writes = Expando<Map<String, Future<void>>>();

  Future<VersionedGameCatalog?> read(String owner) async {
    final row = await store.readOnlyRow(
      owner: owner,
      resource: _resource,
      id: _id,
    );
    final version = row?['version'];
    final rows = row?['rows'];
    if (version is! String ||
        version.isEmpty ||
        rows is! List ||
        rows.any((row) => row is! Map || row['id'] == null)) {
      return null;
    }
    return (
      version: version,
      rows: rows.map((row) => Map<String, dynamic>.from(row as Map)).toList(),
    );
  }

  Future<void> write(String owner, VersionedGameCatalog catalog) => store.put(
    owner: owner,
    resource: _resource,
    id: _id,
    data: {'version': catalog.version, 'rows': catalog.rows},
  );

  /// Reads rows and revision from the same server snapshot. A matching
  /// version does not download or rewrite the catalog.
  Future<
    ({VersionedGameCatalog catalog, Map<String, dynamic>? dashboardSetting})
  >
  refresh(
    SupabaseClient client,
    String owner, {
    required void Function() ensureCurrent,
  }) async {
    final key = owner.trim().toLowerCase();
    final requests = _latest[store] ??= {};
    final request = requests[key] = Object();
    void current() {
      ensureCurrent();
      if (!identical(requests[key], request)) {
        throw StateError('Game catalog refresh superseded');
      }
    }

    try {
      final cached = await read(owner);
      current();
      final setup = await client.rpc(
        'get_my_cloud_transfer_setup',
        params: {'p_catalog_version': cached?.version},
      );
      current();
      if (setup is! Map) throw const FormatException('Invalid transfer setup');
      final version = setup['catalog_version'];
      final rows = setup['game_rows'];
      final setting = setup['dashboard_setting'];
      if (version is! String ||
          version.isEmpty ||
          (rows == null && cached?.version != version) ||
          (rows != null && rows is! List)) {
        throw const FormatException('Invalid game catalog version response');
      }
      if (setting != null && setting is! Map) {
        throw const FormatException('Invalid transfer dashboard settings');
      }
      var catalog = cached;
      if (rows is List) {
        final gameRows = List<Map<String, dynamic>>.from(rows);
        if (gameRows.any((row) => parseStringValue(row['id']).isEmpty)) {
          throw const FormatException('Invalid game catalog row');
        }
        final snapshot = (version: version, rows: gameRows);
        final writes = _writes[store] ??= {};
        final previous = writes[key];
        Future<void> persist() async {
          try {
            await previous;
          } catch (_) {
            // An earlier rejected snapshot must not block the latest write.
          }
          current();
          await write(owner, snapshot);
        }

        final saving = writes[key] = persist();
        try {
          await saving;
        } finally {
          if (identical(writes[key], saving)) writes.remove(key);
        }
        catalog = snapshot;
      }
      current();
      return (
        catalog: catalog!,
        dashboardSetting: setting == null
            ? null
            : Map<String, dynamic>.from(setting as Map),
      );
    } finally {
      if (identical(requests[key], request)) requests.remove(key);
    }
  }
}
