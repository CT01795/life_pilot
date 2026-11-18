import 'package:life_pilot/pages/home/model/event/recommended_event.dart';
import 'package:life_pilot/pages/home/model/place/recommended_place.dart';
import 'package:life_pilot/pages/home/repository/repository_dashboard.dart';

/// Test-only adapter for fakes that control the two recommendation sections.
mixin DashboardRecommendationTestMixin on DashboardRepository {
  @override
  Future<({List<RecommendedEvent> events, List<RecommendedPlace> places})>
  loadRecommendations({
    required String eventCity,
    required String placeCity,
  }) async {
    final results = await Future.wait([
      loadRecommendEvents(eventCity),
      loadRecommendPlaces(placeCity),
    ]);
    return (
      events: results[0] as List<RecommendedEvent>,
      places: results[1] as List<RecommendedPlace>,
    );
  }
}
