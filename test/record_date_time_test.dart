import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/utils/record_date_time.dart';

void main() {
  test('changing a record date preserves its time', () {
    final result = replaceRecordDate(
      DateTime(2026, 9, 15, 14, 35, 22, 123, 456),
      DateTime(2026, 10, 8),
    );

    expect(result, DateTime(2026, 10, 8, 14, 35, 22, 123, 456));
  });

  test('changing record time preserves its date', () {
    final result = replaceRecordTime(
      DateTime(2026, 9, 15, 14, 35, 22, 123, 456),
      const TimeOfDay(hour: 8, minute: 6),
    );

    expect(result, DateTime(2026, 9, 15, 8, 6, 22, 123, 456));
  });
}
