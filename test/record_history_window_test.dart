import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/utils/model_record_history.dart';

void main() {
  final boundaries = [
    (DateTime(2026, 10, 30), DateTime(2026, 10, 1)),
    (DateTime(2026, 10, 1), DateTime(2026, 9, 2)),
    (DateTime(2027, 1, 1), DateTime(2026, 12, 3)),
    (DateTime(2024, 3, 1), DateTime(2024, 2, 1)),
    (DateTime(2025, 3, 1), DateTime(2025, 1, 31)),
    (DateTime(2024, 2, 29), DateTime(2024, 1, 31)),
    (DateTime(2026, 1, 31), DateTime(2026, 1, 2)),
    (DateTime(2026, 12, 31), DateTime(2026, 12, 2)),
  ];
  for (final (day, start) in boundaries) {
    test('inclusive thirty-day window ending $day starts $start', () {
      final anchor = DateTime(day.year, day.month, day.day, 23, 59, 58, 321);
      final window = ModelRecordHistory.windowEndingAt(anchor);
      expect(window.start, start);
      expect(window.end, day);
      expect(window.end.difference(window.start), const Duration(days: 29));
      expect(anchor.hour, 23);
    });
  }

  test(
    'all-record mode preserves the existing epoch and date-only upper bound',
    () {
      final anchor = DateTime(2026, 10, 30, 12, 34);
      final all = ModelRecordHistory.windowEndingAt(anchor, allRecords: true);
      expect(all.start, DateTime.fromMillisecondsSinceEpoch(0));
      expect(all.end, DateTime(2026, 10, 30));
      final recent = ModelRecordHistory.windowEndingAt(anchor);
      expect(recent.start, DateTime(2026, 10, 1));
      expect(recent.end, all.end);
    },
  );

  test('UTC anchors retain the previous calendar-field normalization rule', () {
    final anchor = DateTime.utc(2026, 10, 30, 23, 59);
    final window = ModelRecordHistory.windowEndingAt(anchor);
    final previousEnd = DateTime(anchor.year, anchor.month, anchor.day);
    expect(window.end, previousEnd);
    expect(window.start, previousEnd.subtract(const Duration(days: 29)));
    expect(window.end.isUtc, isFalse);
  });

  test(
    'independent calls retain prior window values without a cached clock',
    () {
      final first = ModelRecordHistory.windowEndingAt(DateTime(2026, 10, 30));
      final next = ModelRecordHistory.windowEndingAt(DateTime(2026, 10, 31));
      expect(first, (
        start: DateTime(2026, 10, 1),
        end: DateTime(2026, 10, 30),
      ));
      expect(next, (start: DateTime(2026, 10, 2), end: DateTime(2026, 10, 31)));
    },
  );

  test('randomized anchors match both controllers original date formulas', () {
    final random = Random(20261030);
    for (var i = 0; i < 1000; i++) {
      final local = DateTime(
        1990 + random.nextInt(70),
        1 + random.nextInt(12),
        1 + random.nextInt(28),
        random.nextInt(24),
        random.nextInt(60),
      );
      final anchor = i.isEven ? local : local.toUtc();
      for (final allRecords in [false, true]) {
        final end = DateTime(anchor.year, anchor.month, anchor.day);
        final expectedStart = allRecords
            ? DateTime.fromMillisecondsSinceEpoch(0)
            : end.subtract(const Duration(days: 29));
        final window = ModelRecordHistory.windowEndingAt(
          anchor,
          allRecords: allRecords,
        );
        expect(window, (
          start: expectedStart,
          end: end,
        ), reason: '$anchor all=$allRecords');
      }
    }
  });
}
