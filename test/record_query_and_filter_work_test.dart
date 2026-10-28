import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/record_statistics/model_record_statistics.dart';
import 'package:life_pilot/record_statistics/model_record_statistics_query.dart';
import 'package:life_pilot/utils/const.dart';
import 'package:life_pilot/utils/record_filter.dart';

void main() {
  for (final kind in RecordStatisticsKind.values) {
    for (final currency in <String?>[null, '', 'TWD', 'USD']) {
      test(
        '$kind/$currency fixed projection preserves table, columns and currency policy',
        () {
          final accounting = kind == RecordStatisticsKind.accounting;
          final query = ModelRecordStatisticsQuery(
            kind: kind,
            now: DateTime(2026, 10, 28),
            currency: currency,
          );
          expect(
            query.tableName,
            accounting
                ? TableNames.accountingDetail
                : TableNames.pointRecordDetail,
          );
          expect(
            query.columns,
            accounting ? 'id,date,value,currency' : 'id,date,value',
          );
          expect(query.currency, accounting ? currency : null);
        },
      );
    }
    for (final now in [
      DateTime(2024, 2, 29),
      DateTime(2026, 12, 31),
      DateTime(2027, 1, 1),
    ]) {
      test(
        '$kind/$now retains inclusive lower and exclusive next-month UTC bounds',
        () {
          final query = ModelRecordStatisticsQuery(kind: kind, now: now);
          expect(
            query.startUtc,
            DateTime(now.year, now.month).toUtc().toIso8601String(),
          );
          expect(
            query.endUtc,
            DateTime(now.year, now.month + 1).toUtc().toIso8601String(),
          );
          final history = ModelRecordStatisticsQuery(
            kind: kind,
            now: now,
            history: true,
          );
          expect(history.startUtc, isNull);
          expect(history.endUtc, isNull);
        },
      );
    }
  }

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
