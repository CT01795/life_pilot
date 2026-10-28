import 'dart:async';
import 'package:life_pilot/utils/logger.dart';
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
    final cached = await gateway.rpcOrBackend(
      'life_pilot_cached_weather',
      params: {'p_lat': lat, 'p_lng': lng},
      backend: () async => null,
    );
    return cached ?? await backend();
  }

  Future<dynamic> holidays({
    required int year,
    required String language,
    required Future<dynamic> Function() backend,
    void Function(dynamic data)? onRefreshed,
  }) async {
    final cached = await gateway.rpcOrBackend(
      'life_pilot_cached_holidays',
      params: {'p_year': year, 'p_language': language},
      backend: () async => null,
    );
    if (cached is! Map || cached['cached'] != true) return backend();
    if (cached['fresh'] != true) {
      // Show existing holidays even while Render is asleep/unavailable.
      unawaited(() async {
        try {
          final refreshed = await backend();
          onRefreshed?.call(refreshed);
        } catch (error, stack) {
          logger.w(
            'Holiday background refresh failed; keeping cached dates',
            error: error,
            stackTrace: stack,
          );
        }
      }());
    }
    return cached;
  }
}
