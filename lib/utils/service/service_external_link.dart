import 'package:life_pilot/event/model_external_destination.dart';
import 'package:life_pilot/utils/logger.dart';
import 'package:url_launcher/url_launcher.dart';

typedef ExternalUriLauncher = Future<bool> Function(Uri uri);

/// Platform launching lives in Service; URL construction stays in Model.
class ServiceExternalLink {
  ServiceExternalLink({ExternalUriLauncher? launcher})
    : _launcher = launcher ?? _launch;

  final ExternalUriLauncher _launcher;

  static Future<bool> _launch(Uri uri) =>
      launchUrl(uri, mode: LaunchMode.externalApplication);

  Future<bool> openUrl(String? url) =>
      _open(ModelExternalDestination.link(url));

  Future<bool> openMap({String? city, String? location}) =>
      _open(ModelExternalDestination.map(city: city, location: location));

  Future<bool> _open(Uri? uri) async {
    if (uri == null) return false;
    try {
      return await _launcher(uri);
    } catch (error, stackTrace) {
      logger.e(
        'Could not open external link.',
        error: error,
        stackTrace: stackTrace,
      );
      return false;
    }
  }
}
