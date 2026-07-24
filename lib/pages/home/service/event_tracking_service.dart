import 'package:life_pilot/utils/api.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../utils/logger.dart';

class EventTrackingService {
  Future<void> launchUrlLink(String? url) async {
    if (url == null) {
      return;
    }
    await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );
  }

  Future<void> incrementEventCounter({
    required String eventId,
    required String eventName,
    required String column,
    required String? account,
  }) async {
    try {
      await apiSupabase.post('event/increment_event_counter', {
        'p_event_id': eventId,
        'p_event_name': eventName,
        'p_column': column,
        'p_account': account,
      });
    } catch (e) {
      logger.e('Error incrementEventCounter $column: $e');
    }
  }

  Future<void> onOpenMap(String? city, String? location) async {
    final locationDisplay = ((city != null && city.isNotEmpty) ||
            (location != null && location.isNotEmpty))
        ? '$city．$location'
        : '';
    if (locationDisplay.isEmpty) return;
    final query = Uri.encodeComponent(locationDisplay);

    // Google Maps 網頁導航 URL
    final googleMapsUrl = 'https://www.google.com/maps/dir/?api=1&destination=$query';

    launchUrlLink(googleMapsUrl);
  }
}
