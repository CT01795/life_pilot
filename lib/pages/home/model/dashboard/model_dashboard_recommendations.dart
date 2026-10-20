import 'package:life_pilot/pages/home/model/event/recommended_event.dart';
import 'package:life_pilot/pages/home/model/place/recommended_place.dart';

/// Decodes dashboard recommendations without owning network or UI state.
/// Attraction order is authoritative from the RPC; only events are re-sorted.
class ModelDashboardRecommendations {
  static final _undated = DateTime(9999);

  static List<RecommendedEvent> events(Iterable<Map<String, dynamic>> rows) =>
      rows.map(RecommendedEvent.fromJson).toList()..sort(_compareEvents);

  static List<RecommendedPlace> places(Iterable<Map<String, dynamic>> rows) =>
      rows.map(RecommendedPlace.fromJson).toList();

  static int _compareEvents(RecommendedEvent left, RecommendedEvent right) {
    var comparison = (left.startDate ?? _undated).compareTo(
      right.startDate ?? _undated,
    );
    if (comparison != 0) return comparison;
    final leftTime = left.startTime;
    final rightTime = right.startTime;
    comparison =
        (leftTime == null ? 1440 : leftTime.hour * 60 + leftTime.minute)
            .compareTo(
              rightTime == null ? 1440 : rightTime.hour * 60 + rightTime.minute,
            );
    if (comparison != 0) return comparison;
    comparison = (left.city ?? '').compareTo(right.city ?? '');
    if (comparison != 0) return comparison;
    comparison = (left.location ?? '').compareTo(right.location ?? '');
    return comparison != 0 ? comparison : left.name.compareTo(right.name);
  }
}
