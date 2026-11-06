import 'package:life_pilot/utils/repository_cloud_gateway.dart';

/// Reads cached coordinates and calls the provider only for missing data.
class RepositoryEventCloudOperations {
  RepositoryEventCloudOperations({RepositoryCloudGateway? gateway})
    : gateway = gateway ?? RepositoryCloudGateway();

  final RepositoryCloudGateway gateway;

  Future<dynamic> geocode({
    required String query,
    required Future<dynamic> Function() backend,
  }) async {
    final cached = await gateway.rpc(
      'life_pilot_cached_geocode',
      params: {'p_query': query},
    );
    // An empty map is a cached "not found", not a cache miss.
    return cached ?? await backend();
  }

  Future<dynamic> backfillCoordinates({
    required String tableName,
    required int offset,
    required Future<dynamic> Function() backend,
  }) async {
    final cached = await gateway.rpc(
      'life_pilot_backfill_cached_map_coordinates',
      params: {'p_table_name': tableName, 'p_offset': offset, 'p_limit': 25},
    );
    if (cached == null) return backend();
    if (cached is! Map) {
      throw const FormatException('Invalid cached backfill response');
    }
    if (cached['needs_backend'] != true) return cached;
    final result = await backend();
    if (result is! Map) {
      throw const FormatException('Invalid backfill response');
    }
    return {
      ...result,
      'saved': (cached['saved'] as num) + (result['saved'] as num),
    };
  }

  Future<dynamic> importPublicEvents({
    required String sourceUrl,
    required List<Map<String, dynamic>> events,
  }) => gateway.rpc(
    'life_pilot_import_public_events',
    params: {'p_source_url': sourceUrl, 'p_events': events},
  );
}
