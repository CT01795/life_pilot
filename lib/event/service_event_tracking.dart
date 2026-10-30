import 'package:life_pilot/utils/supabase.dart';
import 'package:life_pilot/utils/logger.dart';
import 'package:life_pilot/utils/service/service_external_link.dart';

typedef EventCounterWriter =
    Future<void> Function({
      required String eventId,
      required String eventName,
      required String column,
    });

class EventTrackingService {
  EventTrackingService({
    ServiceExternalLink? links,
    EventCounterWriter? counterWriter,
  }) : _links = links ?? ServiceExternalLink(),
       _counterWriter = counterWriter;

  final ServiceExternalLink _links;
  final EventCounterWriter? _counterWriter;

  Future<bool> launchUrlLink(String? url) => _links.openUrl(url);
  Future<bool> onOpenMap(String? city, String? location) =>
      _links.openMap(city: city, location: location);

  Future<void> incrementEventCounter({
    required String eventId,
    required String eventName,
    required String column,
  }) async {
    try {
      final writer = _counterWriter;
      if (writer != null) {
        await writer(eventId: eventId, eventName: eventName, column: column);
      } else {
        await supabase.rpc(
          'increment_event_counter',
          params: {
            'p_event_id': eventId,
            'p_event_name': eventName,
            'p_column': column,
          },
        );
      }
    } catch (error, stackTrace) {
      logger.e(
        'Error incrementEventCounter $column',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<bool> openEventLink({
    required String eventId,
    required String eventName,
    required String? url,
  }) async {
    if (!await launchUrlLink(url)) return false;
    await incrementEventCounter(
      eventId: eventId,
      eventName: eventName,
      column: 'page_views',
    );
    return true;
  }

  Future<bool> openEventMap({
    required String eventId,
    required String eventName,
    required String? city,
    required String? location,
  }) async {
    if (!await onOpenMap(city, location)) return false;
    await incrementEventCounter(
      eventId: eventId,
      eventName: eventName,
      column: 'card_clicks',
    );
    return true;
  }
}
