import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/utils/record_filter.dart';

void main() {
  List<String> filter(
    List<String> rows, {
    required String query,
    String? selectedCategory,
    required String Function(String) label,
  }) => filterRecordItems(
    rows,
    query: query,
    selectedCategory: selectedCategory,
    descriptionOf: (_) => 'description',
    primaryCategoryOf: (r) => r,
    secondaryCategoryOf: (_) => null,
    categoryLabelOf: label,
  );

  test(
    'large same-category search resolves one localized label per category',
    () {
      final calls = <String, int>{};
      final rows = [
        for (var i = 0; i < 10000; i++) i.isEven ? 'food' : 'transport',
      ];
      final result = filter(
        rows,
        query: 'missing',
        label: (category) {
          calls[category] = (calls[category] ?? 0) + 1;
          return category;
        },
      );
      expect(result, isEmpty);
      expect(calls, {'food': 1, 'transport': 1});
    },
  );

  test('language changes between filter calls cannot retain old labels', () {
    expect(filter(['food'], query: '食', label: (_) => '食'), ['food']);
    expect(filter(['food'], query: '食', label: (_) => 'Food'), isEmpty);
    expect(filter(['food'], query: 'FOOD', label: (_) => 'Food'), ['food']);
  });

  test(
    'empty query, category exclusion and earlier matches never request labels',
    () {
      String noLabel(String _) => throw StateError('Label not needed');
      expect(filter(['food'], query: '', label: noLabel), ['food']);
      expect(
        filter(
          ['food'],
          query: 'missing',
          selectedCategory: 'transport',
          label: noLabel,
        ),
        isEmpty,
      );
      expect(filter(['food'], query: 'description', label: noLabel), ['food']);
      expect(
        filterRecordItems(
          ['food'],
          query: 'secondary',
          selectedCategory: null,
          descriptionOf: (_) => 'description',
          primaryCategoryOf: (r) => r,
          secondaryCategoryOf: (_) => 'secondary',
          categoryLabelOf: noLabel,
        ),
        ['food'],
      );
    },
  );
}
