import 'package:life_pilot/pages/home/model/event/recommended_event.dart';
import 'package:life_pilot/pages/home/model/place/recommended_place.dart';
import 'package:life_pilot/pages/home/model/dashboard/model_dashboard_event_ordering.dart';

/// Decodes dashboard recommendations without owning network or UI state.
/// Attraction order is authoritative from the RPC; only events are re-sorted.
class ModelDashboardRecommendations {
  static List<RecommendedEvent> events(Iterable<Map<String, dynamic>> rows) =>
      ModelDashboardEventOrdering.sorted(
        rows.map(RecommendedEvent.fromJson),
        keyOf: (event) {
          final time = event.startTime;
          return DashboardEventOrderKey(
            date: event.startDate,
            minutes: time == null ? 1440 : time.hour * 60 + time.minute,
            city: event.city,
            location: event.location,
            name: event.name,
          );
        },
      );

  static List<RecommendedPlace> places(Iterable<Map<String, dynamic>> rows) =>
      rows.map(RecommendedPlace.fromJson).toList();
}
