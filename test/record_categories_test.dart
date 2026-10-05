import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/utils/record_categories.dart';

void main() {
  test('education is available for both income and expense records', () {
    expect(RecordCategories.accountingIncome, contains('education'));
    expect(RecordCategories.accountingExpense, contains('education'));
    expect(RecordCategories.accounting, contains('education'));
  });
}
