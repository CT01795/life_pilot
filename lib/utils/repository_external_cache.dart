import 'package:life_pilot/utils/repository_cloud_gateway.dart';

/// Reads shared public results, not provider credentials. Cache misses retain
/// the trusted backend's provider access, validation and refresh locking.
class RepositoryExternalCache {
  final RepositoryCloudGateway gateway;
  RepositoryExternalCache({RepositoryCloudGateway? gateway})
    : gateway = gateway ?? RepositoryCloudGateway();

  Future<dynamic> weather({
    required double lat,
    required double lng,
    required Future<dynamic> Function() backend,
  }) async {
    final cached = await gateway.rpc(
      'life_pilot_cached_weather',
      params: {'p_lat': lat, 'p_lng': lng},
    );
    return cached ?? await backend();
  }

  Future<List<dynamic>> weatherBatch({
    required List<({double lat, double lng})> locations,
  }) async {
    if (locations.isEmpty) return const [];
    final result = await gateway.rpc(
      'life_pilot_cached_weather_batch',
      params: {
        'p_locations': [
          for (final location in locations)
            {'lat': location.lat, 'lng': location.lng},
        ],
      },
    );
    if (result is! List || result.length != locations.length) {
      throw const FormatException('Invalid weather batch cache response');
    }
    return List<dynamic>.unmodifiable(result);
  }

  Future<List<Map<String, dynamic>>> holidayYears({
    required List<int> years,
    required String language,
  }) async {
    if (years.isEmpty) return const [];
    final result = await gateway.rpc(
      'life_pilot_cached_holidays_batch',
      params: {'p_years': years, 'p_language': language},
    );
    if (result is! List || result.length != years.length) {
      throw const FormatException('Invalid holiday batch cache response');
    }
    return List<Map<String, dynamic>>.unmodifiable(
      result.map((row) {
        if (row is! Map ||
            row['year'] is! int ||
            row['cached'] is! bool ||
            row['fresh'] is! bool ||
            row['items'] is! List) {
          throw const FormatException('Invalid holiday batch cache row');
        }
        return Map<String, dynamic>.unmodifiable(
          Map<String, dynamic>.from(row),
        );
      }),
    );
  }
}
