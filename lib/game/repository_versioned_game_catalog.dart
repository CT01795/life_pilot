import 'package:life_pilot/local_storage/local_data_store.dart';

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
}
