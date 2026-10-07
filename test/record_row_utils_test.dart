import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/utils/record_row_utils.dart';

void main() {
  final rows = <RecordRow>[
    {
      'id': 'reserved',
      'date': '2025-01-01T08:00:00.000',
      'primary_category': 'reserved',
    },
    {
      'id': 'old',
      'date': '2026-08-01T08:00:00.000',
      'primary_category': 'food',
    },
    {
      'id': 'current',
      'date': '2026-10-07T09:00:00.000',
      'primary_category': 'food',
    },
  ];

  test('date filtering always retains reserved records when requested', () {
    final result = filterRecordRows(
      rows,
      from: DateTime(2026, 10, 1),
      to: DateTime(2026, 10, 31),
    );

    expect(result.map((row) => row['id']), ['current', 'reserved']);
  });

  test('latest fallback adds only the newest regular record', () {
    final result = filterRecordRows(
      rows,
      from: DateTime(2026, 11, 1),
      to: DateTime(2026, 11, 30),
      includeLatestFallback: true,
    );

    expect(result.map((row) => row['id']), ['current', 'reserved']);
  });

  test('record lookup ignores reserved and invalid dates', () {
    final candidates = [
      ...rows,
      {'id': 'invalid', 'date': 'not-a-date', 'primary_category': 'food'},
    ];
    final before = DateTime(2026, 10, 1);

    expect(hasRecordRowBefore(candidates, before), isTrue);
    expect(
      latestRecordRowDateBefore(candidates, before),
      DateTime(2026, 8, 1, 8),
    );
  });

  test('deduplication keeps the last row and sorts newest first', () {
    final result = uniqueRecordRowsNewestFirst([
      {'id': 'same', 'date': '2026-10-01T08:00:00.000'},
      {'id': 'other', 'date': '2026-10-02T08:00:00.000'},
      {'id': 'same', 'date': '2026-10-03T08:00:00.000'},
    ]);

    expect(result.map((row) => row['id']), ['same', 'other']);
    expect(result.first['date'], '2026-10-03T08:00:00.000');
  });
}
