import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/event/model_content_performance.dart';

class _Value {
  _Value(this.value);
  final String value;
  int reads = 0;
  @override
  String toString() {
    reads++;
    return value;
  }
}

void main() {
  test('merge retains parsed items and matches a full reparse of rows', () {
    final first = ModelContentPerformance([
      {'id': 'same', 'page_views': '3', 'like_counts': 2},
      {'id': 'zero', 'start_date': '2026-10-29'},
    ]);
    final second = ModelContentPerformance([
      {'id': 'same', 'page_views': 4, 'like_counts': -1, 'saves': '2'},
    ]);
    final merged = ModelContentPerformance.combine([first, second]);
    final reparsed = ModelContentPerformance([...first.rows, ...second.rows]);
    expect(merged.rows, reparsed.rows);
    expect(merged.totals, reparsed.totals);
    expect(merged.items.first, same(first.items.first));
    expect(merged.items.last, same(second.items.single));
    expect(merged.rows.first, same(first.rows.first));
    expect(merged.rows.map((row) => row['id']), ['same', 'zero', 'same']);
    expect(() => merged.rows.clear(), throwsUnsupportedError);
    expect(() => merged.items.clear(), throwsUnsupportedError);
    expect(() => merged.totals.clear(), throwsUnsupportedError);
  });
  test('empty sources expose all six zero totals', () {
    final merged = ModelContentPerformance.combine([]);
    expect(merged.rows, isEmpty);
    expect(merged.items, isEmpty);
    for (final metric in ContentPerformanceMetric.values) {
      expect(merged.totalFor(metric), 0);
    }
  });
  test('merge never rereads original values or parses dates again', () {
    final date = _Value('2026-10-29');
    final count = _Value('17');
    final first = ModelContentPerformance([
      {'start_date': date, 'page_views': count},
    ]);
    final previous = (date.reads, count.reads);
    final combined = ModelContentPerformance.combine([first, first]);
    expect((date.reads, count.reads), previous);
    expect(combined.totalFor(ContentPerformanceMetric.pageViews), 34);
    expect(combined.items[0], same(combined.items[1]));
  });
  test('filtered source snapshots do not restore excluded zero rows', () {
    final source = ModelContentPerformance([
      {'id': 'zero'},
      {'id': 'keep', 'saves': 1},
    ], statisticsOnly: true);
    expect(ModelContentPerformance.combine([source]).rows.single['id'], 'keep');
  });
}
