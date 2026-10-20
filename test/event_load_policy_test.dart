import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/event/model_event_load_policy.dart';
import 'package:life_pilot/utils/const.dart';

void main() {
  test('memory has a small shared page and preview policy', () {
    final policy = ModelEventLoadPolicy.forTable(TableNames.memoryTrace);
    expect(policy.cloudPageSize, 12);
    expect(policy.previewBatchSize, 3);
    expect(policy.previewBatchSize!, lessThan(policy.cloudPageSize));
    expect(policy, same(ModelEventLoadPolicy.memory));
  });
  for (final table in [
    TableNames.calendarEvents,
    TableNames.recommendEvents,
    TableNames.recommendPlaces,
  ]) {
    test('$table retains standard paging', () {
      final policy = ModelEventLoadPolicy.forTable(table);
      expect(policy.cloudPageSize, 50);
      expect(policy.previewBatchSize, isNull);
      expect(policy, same(ModelEventLoadPolicy.standard));
    });
  }
}
