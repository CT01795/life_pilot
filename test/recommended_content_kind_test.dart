import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/event/page_recommended_content.dart';
import 'package:life_pilot/utils/const.dart';

void main() {
  test('recommended event keeps its refresh and table configuration', () {
    expect(RecommendedContentKind.event.tableName, TableNames.recommendEvents);
    expect(RecommendedContentKind.event.autoRefreshPublicEvents, isTrue);
  });

  test('recommended attraction keeps its table without event refresh', () {
    expect(
      RecommendedContentKind.attraction.tableName,
      TableNames.recommendPlaces,
    );
    expect(RecommendedContentKind.attraction.autoRefreshPublicEvents, isFalse);
  });
}
