import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/event/model_content_performance.dart';
import 'package:life_pilot/vendor/model_vendor_account.dart';

final _now = DateTime(2026, 10, 30);
Map<String, dynamic> _row(
  String id, {
  DateTime? start,
  Object? end,
  bool approved = false,
}) => {
  'id': id,
  'name': id,
  'city': 'City',
  'start_date': start,
  'end_date': end,
  'is_approved': approved,
  'page_views': 1,
};

List<VendorRecentSubmission> _legacy(
  ModelContentPerformance events,
  ModelContentPerformance places,
) {
  final rows = <VendorRecentSubmission>[];
  void collect(ModelContentPerformance source, bool activity) {
    for (final item in source.items) {
      rows.add(
        VendorRecentSubmission(
          id: item.id,
          name: item.name,
          city: item.city,
          isActivity: activity,
          isApproved: item.approved,
          startDate: item.starts,
          endDate: item.ends,
        ),
      );
    }
  }

  collect(events, true);
  collect(places, false);
  rows.sort((left, right) {
    if (left.isApproved != right.isApproved) return left.isApproved ? 1 : -1;
    final a = left.startDate ?? left.endDate,
        b = right.startDate ?? right.endDate;
    if (a == null && b == null) return 0;
    if (a == null) return 1;
    if (b == null) return -1;
    final upcomingA = !a.isBefore(_now), upcomingB = !b.isBefore(_now);
    if (upcomingA != upcomingB) return upcomingA ? -1 : 1;
    return upcomingA ? a.compareTo(b) : b.compareTo(a);
  });
  return rows.take(5).toList();
}

Iterable<Object> _signature(Iterable<VendorRecentSubmission> values) =>
    values.map(
      (r) => (
        r.id,
        r.name,
        r.city,
        r.isActivity,
        r.isApproved,
        r.startDate,
        r.endDate,
      ),
    );
VendorContentMetrics _metrics(
  ModelContentPerformance events,
  ModelContentPerformance places,
) => VendorContentMetrics.fromPerformance(
  events: events,
  attractions: places,
  now: _now,
);

class _CountedDate implements DateTime {
  _CountedDate(this.value, this.compared);
  final DateTime value;
  final void Function() compared;
  DateTime _unwrap(DateTime date) => date is _CountedDate ? date.value : date;
  @override
  DateTime toLocal() => this;
  @override
  bool isBefore(DateTime other) => value.isBefore(_unwrap(other));
  @override
  int compareTo(DateTime other) {
    compared();
    return value.compareTo(_unwrap(other));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('ordered ten-thousand-row source uses bounded preview comparisons', () {
    var comparisons = 0;
    final events = ModelContentPerformance(
      List.generate(
        10000,
        (i) => _row(
          '$i',
          start: _CountedDate(
            _now.add(Duration(minutes: i)),
            () => comparisons++,
          ),
        ),
      ),
    );
    final result = _metrics(events, ModelContentPerformance([]));
    expect(result.recentSubmissions.map((r) => r.id), [
      '0',
      '1',
      '2',
      '3',
      '4',
    ]);
    expect(comparisons, 10005);
    expect(result.pending, 10000);
    expect(result.activeEvents, 10000);
    expect(result.performance.totals['page_views'], 10000);
  });

  test('pending, upcoming, past and undated priorities remain unchanged', () {
    final events = ModelContentPerformance([
      _row('approved', start: _now, approved: true),
      _row('undated'),
      _row('old', start: _now.subtract(const Duration(days: 20))),
      _row('future', start: _now.add(const Duration(days: 2))),
      _row('today', start: _now),
      _row('recent', start: _now.subtract(const Duration(days: 1))),
    ]);
    final places = ModelContentPerformance([]);
    expect(
      _signature(_metrics(events, places).recentSubmissions),
      _signature(_legacy(events, places)),
    );
    expect(_metrics(events, places).recentSubmissions.map((r) => r.id), [
      'today',
      'future',
      'recent',
      'old',
      'undated',
    ]);
  });

  test(
    'empty through five-row previews remain read-only without changing sources',
    () {
      for (var count = 0; count <= 5; count++) {
        final events = ModelContentPerformance(
          List.generate(
            count,
            (i) => _row('$i', start: _now.add(Duration(days: count - i))),
          ),
        );
        final before = events.items;
        final places = ModelContentPerformance([]);
        final result = _metrics(events, places);
        expect(
          _signature(result.recentSubmissions),
          _signature(_legacy(events, places)),
        );
        expect(events.items, same(before));
        expect(() => result.recentSubmissions.clear(), throwsUnsupportedError);
      }
    },
  );

  test('all equal keys match the original full-sort tie order', () {
    final events = ModelContentPerformance(
      List.generate(100, (i) => _row('e$i', start: _now)),
    );
    final places = ModelContentPerformance(
      List.generate(100, (i) => _row('p$i', start: _now)),
    );
    expect(
      _signature(_metrics(events, places).recentSubmissions),
      _signature(_legacy(events, places)),
    );
  });

  test('ties at the fifth-row boundary retain the original choice', () {
    final events = ModelContentPerformance(
      List.generate(
        40,
        (i) => _row('$i', start: _now.add(Duration(days: i < 4 ? i : 4))),
      ),
    );
    final places = ModelContentPerformance([]);
    expect(
      _signature(_metrics(events, places).recentSubmissions),
      _signature(_legacy(events, places)),
    );
  });

  test('identical IDs in different content sources are not deduplicated', () {
    final events = ModelContentPerformance([_row('same', start: _now)]);
    final places = ModelContentPerformance([
      _row('same', start: _now.add(const Duration(days: 1))),
    ]);
    final result = _metrics(events, places);
    expect(result.recentSubmissions.map((r) => (r.id, r.isActivity)), [
      ('same', true),
      ('same', false),
    ]);
  });

  test('end-date fallback and open-ended activity rules remain separate', () {
    final events = ModelContentPerformance([
      _row('end-only', end: _now),
      _row('past-start', start: _now.subtract(const Duration(days: 1))),
      _row(
        'invalid-end',
        start: _now.subtract(const Duration(days: 2)),
        end: '',
      ),
    ]);
    final places = ModelContentPerformance([]);
    final result = _metrics(events, places);
    expect(
      _signature(result.recentSubmissions),
      _signature(_legacy(events, places)),
    );
    expect(result.activeEvents, 2);
  });

  test(
    'randomized ties, dates and mixed content match full sorting exactly',
    () {
      final random = Random(20261030);
      for (var batch = 0; batch < 200; batch++) {
        List<Map<String, dynamic>> rows(String kind) => List.generate(
          80,
          (i) => _row(
            '$kind$i',
            start: random.nextInt(5) == 0
                ? null
                : _now.add(Duration(days: random.nextInt(21) - 10)),
            end: random.nextBool()
                ? null
                : _now.add(Duration(days: random.nextInt(21) - 10)),
            approved: random.nextBool(),
          ),
        );
        final events = ModelContentPerformance(rows('e')),
            places = ModelContentPerformance(rows('p'));
        expect(
          _signature(_metrics(events, places).recentSubmissions),
          _signature(_legacy(events, places)),
          reason: 'batch $batch',
        );
      }
    },
  );

  test(
    'non-preview rows still contribute to counts and all performance totals',
    () {
      final events = ModelContentPerformance(
        List.generate(
          100,
          (i) =>
              _row('e$i', start: _now.add(Duration(days: i)), approved: true),
        ),
      );
      final places = ModelContentPerformance(
        List.generate(
          50,
          (i) => _row('p$i', start: _now.add(Duration(days: i))),
        ),
      );
      final result = _metrics(events, places);
      expect(result.recentSubmissions, hasLength(5));
      expect(result.published, 100);
      expect(result.pending, 50);
      expect(result.activeEvents, 100);
      expect(result.activeAttractions, 50);
      expect(result.performance.items, hasLength(150));
      expect(result.performance.totals['page_views'], 150);
    },
  );
}
