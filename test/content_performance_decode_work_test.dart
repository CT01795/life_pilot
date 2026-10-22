import 'dart:collection';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/event/model_content_performance.dart';

class _MetricsOnlyRow extends MapBase<String, dynamic> {
  int reads = 0;
  @override
  dynamic operator [](Object? key) {
    if (!contentPerformanceColumns.contains(key)) {
      throw StateError('Excluded row must not decode $key');
    }
    reads++;
    return '0';
  }

  @override
  Iterable<String> get keys => throw StateError('Do not copy excluded rows');
  @override
  void operator []=(String key, dynamic value) => throw UnsupportedError('row');
  @override
  void clear() => throw UnsupportedError('row');
  @override
  dynamic remove(Object? key) => throw UnsupportedError('row');
}

class _CountedValue {
  int parses = 0;
  @override
  String toString() {
    parses++;
    return '4';
  }
}

void main() {
  test('zero-statistics rows skip metadata, dates and source copying', () {
    final row = _MetricsOnlyRow();
    final model = ModelContentPerformance([row], statisticsOnly: true);
    expect(model.items, isEmpty);
    expect(model.rows, isEmpty);
    expect(model.visibleMetrics, isEmpty);
    expect(row.reads, contentPerformanceColumns.length);
  });
  for (final statisticsOnly in [false, true]) {
    test('$statisticsOnly: retained metric values are parsed only once', () {
      final value = _CountedValue();
      final model = ModelContentPerformance([
        {'id': 'a', 'name': 'A', 'page_views': value},
      ], statisticsOnly: statisticsOnly);
      final item = model.items.single;
      expect(value.parses, 1);
      expect(item.maximum, 4);
      expect(item.countFor(ContentPerformanceMetric.pageViews), 4);
      expect(model.totalFor(ContentPerformanceMetric.pageViews), 4);
      expect(() => item.counts.clear(), throwsUnsupportedError);
    });
  }
  test('negative counts stay visible and preserve maximum and total rules', () {
    final model = ModelContentPerformance([
      {'id': 'negative', 'like_counts': -2},
      {'id': 'zero', 'like_counts': 0},
    ], statisticsOnly: true);
    expect(model.items.single.id, 'negative');
    expect(model.items.single.maximum, 1);
    expect(model.items.single.hasStatistics, isTrue);
    expect(model.totalFor(ContentPerformanceMetric.likes), -2);
  });
}
