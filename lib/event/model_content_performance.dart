import 'dart:convert';
import 'package:life_pilot/utils/value_parser.dart';
import 'package:life_pilot/event/model_content_performance_period.dart';

const contentPerformanceColumns = [
  'page_views',
  'card_clicks',
  'registration_clicks',
  'saves',
  'like_counts',
  'dislike_counts',
];

int compareContentPerformance(
  Map<String, dynamic> left,
  Map<String, dynamic> right, {
  bool attractions = false,
}) => ContentPerformanceItem(
  left,
).compare(ContentPerformanceItem(right), attractions: attractions);

/// Quote filter values so commas, parentheses and quotes cannot alter the query.
String contentPerformanceSearchFilter(String keyword) {
  final text = keyword
      .trim()
      .replaceAll('\\', '\\\\')
      .replaceAll('%', '\\%')
      .replaceAll('_', '\\_');
  final pattern = jsonEncode('%$text%');
  return 'name.ilike.$pattern,city.ilike.$pattern';
}

class ModelContentPerformance {
  final List<Map<String, dynamic>> rows;
  final List<ContentPerformanceItem> items;
  final Map<String, int> totals;
  ModelContentPerformance._(this.rows, this.items, this.totals);
  factory ModelContentPerformance(
    List<Map<String, dynamic>> rows, {
    bool sortByExpiry = false,
    bool attractions = false,
    bool statisticsOnly = false,
  }) {
    final items = <ContentPerformanceItem>[];
    final totals = {for (final column in contentPerformanceColumns) column: 0};
    for (final row in rows) {
      final item = ContentPerformanceItem(row);
      if (statisticsOnly && !item.hasStatistics) continue;
      items.add(item);
      for (var i = 0; i < contentPerformanceColumns.length; i++) {
        totals[contentPerformanceColumns[i]] =
            totals[contentPerformanceColumns[i]]! + item.counts[i];
      }
    }
    if (sortByExpiry) {
      items.sort((a, b) => a.compare(b, attractions: attractions));
    }
    return ModelContentPerformance._(
      List.unmodifiable(items.map((item) => item.source)),
      List.unmodifiable(items),
      Map.unmodifiable(totals),
    );
  }
}

/// Parsed once per response, never again during sorting or card rebuilds.
class ContentPerformanceItem implements Comparable<ContentPerformanceItem> {
  final Map<String, dynamic> source;
  final String id, name, city;
  final bool approved;
  final DateTime? expires, starts, ends;
  DateTime? get visibleEndDate =>
      ends != null && ends!.year < 2100 ? ends : null;
  final List<int> counts;
  final int maximum;
  bool get hasStatistics => counts.any((value) => value != 0);
  ContentPerformanceItem._(
    this.source,
    this.id,
    this.name,
    this.city,
    this.approved,
    this.expires,
    this.starts,
    this.ends,
    this.counts,
    this.maximum,
  );
  factory ContentPerformanceItem(Map<String, dynamic> row) {
    final counts = <int>[];
    var maximum = 1;
    for (final column in contentPerformanceColumns) {
      final value = parseIntValue(row[column]);
      counts.add(value);
      if (value > maximum) maximum = value;
    }
    return ContentPerformanceItem._(
      Map.unmodifiable(row),
      parseStringValue(row['id']),
      parseStringValue(row['name']),
      parseStringValue(row['city']),
      row['is_approved'] == true,
      ContentPerformancePeriod.expiration(row),
      tryParseDateTimeValue(row['start_date'], toLocal: true),
      tryParseDateTimeValue(row['end_date'], toLocal: true),
      List.unmodifiable(counts),
      maximum,
    );
  }
  @override
  int compareTo(ContentPerformanceItem other) => compare(other);

  int compare(ContentPerformanceItem other, {bool attractions = false}) {
    int byDate(DateTime? a, DateTime? b, {bool ascending = true}) => a == null
        ? (b == null ? 0 : 1)
        : b == null
        ? -1
        : ascending
        ? a.compareTo(b)
        : b.compareTo(a);
    var order = byDate(expires, other.expires);
    if (order != 0) return order;
    order = city.compareTo(other.city);
    if (order != 0) return order;
    order = byDate(starts, other.starts, ascending: attractions);
    if (order != 0) return order;
    order = name.compareTo(other.name);
    return order != 0 ? order : id.compareTo(other.id);
  }
}
