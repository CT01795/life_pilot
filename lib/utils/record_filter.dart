import 'package:life_pilot/utils/value_parser.dart';

List<T> filterRecordItems<T>(
  Iterable<T> records, {
  required String query,
  required String? selectedCategory,
  required String Function(T record) descriptionOf,
  required String Function(T record) primaryCategoryOf,
  required String? Function(T record) secondaryCategoryOf,
  required String Function(String category) categoryLabelOf,
}) {
  final normalizedQuery = normalizeStringValue(query);
  // Labels are stable within one filter call. Do not cache them across locale
  // changes, and preserve short-circuiting for description/secondary matches.
  final categoryLabels = <String, String>{};
  return records
      .where((record) {
        final primaryCategory = primaryCategoryOf(record);
        if (selectedCategory != null && primaryCategory != selectedCategory) {
          return false;
        }
        if (normalizedQuery.isEmpty) return true;
        return descriptionOf(record).toLowerCase().contains(normalizedQuery) ||
            (secondaryCategoryOf(record) ?? '').toLowerCase().contains(
              normalizedQuery,
            ) ||
            categoryLabels
                .putIfAbsent(
                  primaryCategory,
                  () => categoryLabelOf(primaryCategory).toLowerCase(),
                )
                .contains(normalizedQuery);
      })
      .toList(growable: false);
}

T? firstRecordOutsideCategory<T>(
  Iterable<T> records, {
  required String excludedCategory,
  required String Function(T record) primaryCategoryOf,
}) {
  for (final record in records) {
    if (primaryCategoryOf(record) != excludedCategory) return record;
  }
  return null;
}
