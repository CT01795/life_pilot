import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/utils/sort_if_needed.dart';

void main() {
  test('empty and singleton lists never compare values', () {
    var comparisons = 0;
    int compare(int a, int b) {
      comparisons++;
      return a.compareTo(b);
    }

    final empty = <int>[];
    final single = [1];
    sortIfNeeded(empty, compare);
    sortIfNeeded(single, compare);
    expect(comparisons, 0);
    expect(empty, isEmpty);
    expect(single, [1]);
  });

  for (final descending in [false, true]) {
    test(
      'strictly ordered large input compares adjacent pairs only ($descending)',
      () {
        final values = List.generate(10000, (i) => descending ? 10000 - i : i);
        final before = List.of(values);
        var comparisons = 0;
        sortIfNeeded(values, (a, b) {
          comparisons++;
          return descending ? b.compareTo(a) : a.compareTo(b);
        });
        expect(values, before);
        expect(comparisons, values.length - 1);
      },
    );
  }

  test('equal keys deliberately follow the legacy tie sort path', () {
    final source = List.generate(150, (i) => (id: i, rank: 0));
    final expected = List.of(source);
    var legacyComparisons = 0;
    expected.sort((a, b) {
      legacyComparisons++;
      return a.rank.compareTo(b.rank);
    });
    final actual = List.of(source);
    var comparisons = 0;
    sortIfNeeded(actual, (a, b) {
      comparisons++;
      return a.rank.compareTo(b.rank);
    });
    expect(actual, expected);
    expect(comparisons, legacyComparisons + 1);
  });

  test('first reversed pair enters the normal sort immediately', () {
    final source = List.generate(150, (i) => 150 - i);
    var legacyComparisons = 0;
    final expected = List.of(source)
      ..sort((a, b) {
        legacyComparisons++;
        return a.compareTo(b);
      });
    var comparisons = 0;
    final actual = List.of(source);
    sortIfNeeded(actual, (a, b) {
      comparisons++;
      return a.compareTo(b);
    });
    expect(actual, expected);
    expect(comparisons, legacyComparisons + 1);
  });

  test('disorder near the end is not mistaken for a sorted list', () {
    final values = List.generate(100, (i) => i)..add(-1);
    final expected = List.of(values)..sort();
    sortIfNeeded(values, (a, b) => a.compareTo(b));
    expect(values, expected);
  });

  test('randomized duplicates and ties match List.sort exactly', () {
    final random = Random(20261030);
    for (var iteration = 0; iteration < 150; iteration++) {
      final source = List.generate(
        120,
        (i) => (id: i, rank: random.nextInt(8)),
      );
      int compare(({int id, int rank}) a, ({int id, int rank}) b) =>
          a.rank.compareTo(b.rank);
      final expected = List.of(source)..sort(compare);
      final actual = List.of(source);
      sortIfNeeded(actual, compare);
      expect(actual, expected, reason: 'iteration $iteration');
    }
  });
}
