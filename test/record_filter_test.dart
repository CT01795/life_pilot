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
}

class _Record {
  const _Record(this.description, this.primaryCategory, this.secondaryCategory);

  final String description;
  final String primaryCategory;
  final String? secondaryCategory;
}
