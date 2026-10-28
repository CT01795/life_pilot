import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/event/model_content_performance.dart';

class _DateReads {
  int conversions = 0;
}

class _DateValue implements DateTime {
  final DateTime value;
  final _DateReads reads;
  _DateValue(this.value, this.reads);
  @override
  DateTime toLocal() {
    reads.conversions++;
    return value.toLocal();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('same raw date is converted once and reused for both dates', () {
    final reads = _DateReads();
    final date = _DateValue(DateTime.utc(2026, 10, 28), reads);
    final item = ContentPerformanceItem({'start_date': date, 'end_date': date});
    expect(reads.conversions, 1);
    expect(identical(item.starts, item.ends), isTrue);
    expect(item.expires, item.ends);
  });

  test('different dates retain separate conversions and expiration', () {
    final reads = _DateReads();
    final first = DateTime.utc(2026, 10, 28);
    final last = DateTime.utc(2026, 10, 30);
    final item = ContentPerformanceItem({
      'start_date': _DateValue(first, reads),
      'end_date': _DateValue(last, reads),
    });
    expect(reads.conversions, 2);
    expect(item.starts, first.toLocal());
    expect(item.ends, last.toLocal());
    expect(item.expires, last.toLocal());
  });

  for (final dates in [
    <String, dynamic>{},
    {'start_date': '2026-10-28'},
    {'end_date': '2026-10-29'},
    {'start_date': 'bad', 'end_date': 'bad'},
    {'start_date': '2026-10-28', 'end_date': '2026-10-28'},
  ]) {
    test(
      'null/invalid/same-date mapping preserves original results: $dates',
      () {
        DateTime? parse(dynamic raw) =>
            raw == null ? null : DateTime.tryParse(raw)?.toLocal();
        final item = ContentPerformanceItem(dates);
        expect(item.starts, parse(dates['start_date']));
        expect(item.ends, parse(dates['end_date']));
        expect(
          item.expires,
          parse(dates['end_date']) ?? parse(dates['start_date']),
        );
      },
    );
  }

  for (final row in [
    <String, dynamic>{},
    {'page_views': null, 'saves': 'bad'},
    {'page_views': -5, 'saves': 0},
    {'page_views': '12', 'saves': 3},
    {'page_views': 1, 'saves': 1},
  ]) {
    test(
      'lazy maximum and retained nonzero flag match original semantics: $row',
      () {
      final source = Map<String, dynamic>.from(row);
      final item = ContentPerformanceItem(source);
        final expected = item.counts.fold<int>(1, (a, b) => a > b ? a : b);
        final hasStatistics = item.counts.any((n) => n != 0);
        expect(item.hasStatistics, hasStatistics);
      source['page_views'] = 999;
        expect(item.maximum, expected);
        expect(item.maximum, expected);
        expect(item.hasStatistics, hasStatistics);
      },
    );
  }
}
