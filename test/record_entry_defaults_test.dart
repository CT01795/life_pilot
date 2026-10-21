import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/utils/model_record_entry_defaults.dart';

void main() {
  test('no latest detail leaves the caller default untouched', () {
    expect(
      ModelRecordEntryDefaults.accountingDirectionAndCategory(null),
      isNull,
    );
    expect(ModelRecordEntryDefaults.pointDirectionAndCategory(null), isNull);
  });
  test('zero retains distinct accounting and point direction rules', () {
    expect(
      ModelRecordEntryDefaults.accountingDirectionAndCategory({'value': 0}),
      (false, 'uncategorized'),
    );
    expect(ModelRecordEntryDefaults.pointDirectionAndCategory({'value': 0}), (
      true,
      'uncategorized',
    ));
  });
  test('fractional numbers and text retain signs and categories', () {
    for (final value in [-0.0001, '-23.4567', 23.4567, '0.0001']) {
      final expected = num.parse(value.toString()) > 0;
      final row = {'value': value, 'primary_category': 'food'};
      expect(ModelRecordEntryDefaults.accountingDirectionAndCategory(row), (
        expected,
        'food',
      ));
      expect(ModelRecordEntryDefaults.pointDirectionAndCategory(row), (
        expected,
        'food',
      ));
    }
  });
  test('missing or malformed values keep previous zero fallback', () {
    for (final value in [null, 'bad']) {
      expect(
        ModelRecordEntryDefaults.accountingDirectionAndCategory({
          'value': value,
        }),
        (false, 'uncategorized'),
      );
      expect(
        ModelRecordEntryDefaults.pointDirectionAndCategory({'value': value}),
        (true, 'uncategorized'),
      );
    }
  });
  test('an explicitly empty category is not silently replaced', () {
    expect(
      ModelRecordEntryDefaults.accountingDirectionAndCategory({
        'value': 2,
        'primary_category': '',
      }),
      (true, ''),
    );
  });
  test('currency selects newest valid account of the requested category', () {
    final rows = [
      {
        'is_valid': true,
        'category': 'personal',
        'created_at': '2026-10-01',
        'main_currency': 'USD',
      },
      {
        'is_valid': true,
        'category': 'personal',
        'created_at': '2026-10-20',
        'main_currency': 'JPY',
      },
      {
        'is_valid': false,
        'category': 'personal',
        'created_at': '2026-10-21',
        'main_currency': 'KRW',
      },
      {
        'is_valid': true,
        'category': 'trip',
        'created_at': '2026-10-21',
        'main_currency': 'EUR',
      },
    ];
    expect(
      ModelRecordEntryDefaults.latestAccountCurrency(rows, 'personal'),
      'JPY',
    );
    expect(rows.first['main_currency'], 'USD');
  });
  test('empty/missing currency follows previous TWD fallback policy', () {
    expect(
      ModelRecordEntryDefaults.latestAccountCurrency([], 'personal'),
      'TWD',
    );
    expect(
      ModelRecordEntryDefaults.latestAccountCurrency([
        {'is_valid': true, 'category': 'personal'},
      ], 'personal'),
      'TWD',
    );
    expect(
      ModelRecordEntryDefaults.latestAccountCurrency([
        {'is_valid': true, 'category': 'personal', 'main_currency': ''},
      ], 'personal'),
      '',
    );
  });
  test('equal creation keys retain first source account', () {
    expect(
      ModelRecordEntryDefaults.latestAccountCurrency([
        {'is_valid': true, 'category': 'personal', 'main_currency': 'USD'},
        {'is_valid': true, 'category': 'personal', 'main_currency': 'JPY'},
      ], 'personal'),
      'USD',
    );
  });
  test('read-only one-pass input works without sorting a list', () {
    var visits = 0;
    Iterable<Map<String, dynamic>> rows() sync* {
      for (var i = 0; i < 5000; i++) {
        visits++;
        yield Map<String, dynamic>.unmodifiable({
          'is_valid': true,
          'category': 'personal',
          'created_at': '$i'.padLeft(5, '0'),
          'main_currency': '$i',
        });
      }
    }

    expect(
      ModelRecordEntryDefaults.latestAccountCurrency(rows(), 'personal'),
      '4999',
    );
    expect(visits, 5000);
  });
}
