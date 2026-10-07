import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/utils/record_filter.dart';

void main() {
  const records = [
    _Record('Breakfast', 'food', 'restaurant'),
    _Record('Bus', 'transport', 'commute'),
    _Record('Bonus', 'income', null),
  ];

  List<_Record> filter({String query = '', String? category}) =>
      filterRecordItems(
        records,
        query: query,
        selectedCategory: category,
        descriptionOf: (record) => record.description,
        primaryCategoryOf: (record) => record.primaryCategory,
        secondaryCategoryOf: (record) => record.secondaryCategory,
        categoryLabelOf: (value) => switch (value) {
          'food' => 'Food',
          'transport' => 'Transport',
          'income' => 'Income',
          _ => value,
        },
      );

  test('filters records by primary category', () {
    expect(filter(category: 'food'), [records.first]);
  });

  test('matches description, secondary category, and localized category', () {
    expect(filter(query: 'bus'), [records[1]]);
    expect(filter(query: 'restaurant'), [records[0]]);
    expect(filter(query: 'income'), [records[2]]);
  });

  test('combines category and search filters', () {
    expect(filter(query: 'bus', category: 'food'), isEmpty);
  });

  test('returns the first record outside the excluded category', () {
    const withReservedFirst = [
      _Record('Balance', 'reserved', null),
      ...records,
    ];

    final result = firstRecordOutsideCategory(
      withReservedFirst,
      excludedCategory: 'reserved',
      primaryCategoryOf: (record) => record.primaryCategory,
    );

    expect(result, records.first);
  });

  test('returns null when every record has the excluded category', () {
    final result = firstRecordOutsideCategory(
      const [_Record('Balance', 'reserved', null)],
      excludedCategory: 'reserved',
      primaryCategoryOf: (record) => record.primaryCategory,
    );

    expect(result, isNull);
  });
}

class _Record {
  const _Record(this.description, this.primaryCategory, this.secondaryCategory);

  final String description;
  final String primaryCategory;
  final String? secondaryCategory;
}
