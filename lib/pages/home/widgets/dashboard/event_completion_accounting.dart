import 'package:life_pilot/accounting/model_accounting_preview.dart';

List<AccountingPreview> buildEventAccountingRecords({
  required String eventName,
  required String eventId,
  required String currency,
  required DateTime recordedAt,
  num? incomeValue,
  required String incomeCategory,
  num? expenseValue,
  required String expenseCategory,
}) => [
  if (incomeValue != null)
    AccountingPreview(
      description: eventName,
      value: incomeValue,
      currency: currency,
      exchangeRate: null,
      eventId: eventId,
      date: recordedAt,
      primaryCategory: incomeCategory,
    ),
  if (expenseValue != null)
    AccountingPreview(
      description: eventName,
      value: -expenseValue,
      currency: currency,
      exchangeRate: null,
      eventId: eventId,
      date: recordedAt,
      primaryCategory: expenseCategory,
    ),
];
