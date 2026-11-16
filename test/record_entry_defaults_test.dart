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
}
