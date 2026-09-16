import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/pages/home/widgets/dashboard/event_completion_accounting.dart';

void main() {
  test('creates income and expense records in one event review batch', () {
    final recordedAt = DateTime(2026, 9, 16, 18, 30);

    final records = buildEventAccountingRecords(
      eventName: 'Family trip',
      eventId: 'event-1',
      currency: 'TWD',
      recordedAt: recordedAt,
      incomeValue: 1200.5,
      incomeCategory: 'other',
      expenseValue: 345.75,
      expenseCategory: 'leisure',
    );

    expect(records, hasLength(2));
    expect(records[0].value, 1200.5);
    expect(records[0].primaryCategory, 'other');
    expect(records[1].value, -345.75);
    expect(records[1].primaryCategory, 'leisure');
    expect(records.every((record) => record.eventId == 'event-1'), isTrue);
    expect(records.every((record) => record.date == recordedAt), isTrue);
  });

  test('omits an accounting direction that the user did not enter', () {
    final records = buildEventAccountingRecords(
      eventName: 'Walk',
      eventId: 'event-2',
      currency: 'TWD',
      recordedAt: DateTime(2026, 9, 16),
      incomeCategory: 'other',
      expenseValue: 50,
      expenseCategory: 'leisure',
    );

    expect(records, hasLength(1));
    expect(records.single.value, -50);
  });
}
