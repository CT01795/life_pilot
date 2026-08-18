import 'package:life_pilot/utils/api.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../utils/logger.dart';

class EventTrackingService {
  Future<bool> launchUrlLink(String? url) async {
    if (url == null || url.trim().isEmpty) return false;
    try {
      return await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
    } catch (error, stackTrace) {
      logger.e('Could not open external link.',
          error: error, stackTrace: stackTrace);
      return false;
    }
  }

  Future<void> incrementEventCounter({
    required String eventId,
    required String eventName,
    required String column,
    required String? account,
  }) async {
    try {
      await supabase.rpc(
        'increment_event_counter',
        params: {
          'p_event_id': eventId,
          'p_event_name': eventName,
          'p_column': column,
          'p_account': account,
        },
      );
    } catch (e) {
      logger.e('Error incrementEventCounter $column: $e');
    }
  }

  Future<bool> onOpenMap(String? city, String? location) async {
    final locationDisplay = ((city != null && city.isNotEmpty) ||
            (location != null && location.isNotEmpty))
        ? '$city．$location'
        : '';
    if (locationDisplay.isEmpty) return false;
    final query = Uri.encodeComponent(locationDisplay);

    // Google Maps 網頁導航 URL
    final googleMapsUrl = 'https://www.google.com/maps/dir/?api=1&destination=$query';

    return launchUrlLink(googleMapsUrl);
  }
}
