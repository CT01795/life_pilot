import 'dart:convert';
import 'package:life_pilot/utils/value_parser.dart';

enum ContentPerformanceMetric {
  pageViews('page_views'),
  navigationClicks('card_clicks'),
  registrationClicks('registration_clicks'),
  saves('saves'),
  likes('like_counts'),
  dislikes('dislike_counts');

  final String column;
  const ContentPerformanceMetric(this.column);
}

/// Locale-independent presentation data; icon/label/number formatting stays in
/// the View. Keep the same metric order and omit only exact zero values.
class ContentPerformanceMetricValue {
  final ContentPerformanceMetric metric;
  final int count;
  const ContentPerformanceMetricValue(this.metric, this.count);
}

List<ContentPerformanceMetricValue> _nonZeroMetricValues(
  int Function(ContentPerformanceMetric) countFor,
) {
  final values = <ContentPerformanceMetricValue>[];
  for (final metric in ContentPerformanceMetric.values) {
    final count = countFor(metric);
    if (count != 0) values.add(ContentPerformanceMetricValue(metric, count));
  }
  return List.unmodifiable(values);
}

final contentPerformanceColumns = List<String>.unmodifiable(
  ContentPerformanceMetric.values.map((metric) => metric.column),
);

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
  int totalFor(ContentPerformanceMetric metric) => totals[metric.column]!;
  late final List<ContentPerformanceMetricValue> visibleMetrics =
      _nonZeroMetricValues(totalFor);

  /// Share of the same metric across this query's filtered result, not people.
  double shareFor(
    ContentPerformanceItem item,
    ContentPerformanceMetric metric,
  ) {
    final total = totalFor(metric);
    return total > 0 ? (item.countFor(metric) / total).clamp(0.0, 1.0) : 0.0;
  }

  ModelContentPerformance._(this.rows, this.items, this.totals);
  factory ModelContentPerformance(
    List<Map<String, dynamic>> rows, {
    bool sortByExpiry = false,
    bool attractions = false,
    bool statisticsOnly = false,
  }) {
    final items = <ContentPerformanceItem>[];
    // Metric indexes are shared with item counts. Avoid repeated string-key
    // lookups for every row; publish the existing named-column API only once.
    final totalCounts = List<int>.filled(contentPerformanceColumns.length, 0);
    for (final row in rows) {
      final metrics = _ContentMetricCounts(row);
      // Excluded rows need neither date parsing nor a retained source copy.
      if (statisticsOnly && !metrics.hasStatistics) continue;
      final item = ContentPerformanceItem._fromCounts(row, metrics);
      items.add(item);
      for (var i = 0; i < totalCounts.length; i++) {
        totalCounts[i] += item.counts[i];
      }
    }
    if (sortByExpiry) {
      items.sort((a, b) => a.compare(b, attractions: attractions));
    }
    return ModelContentPerformance._(
      List.unmodifiable(items.map((item) => item.source)),
      List.unmodifiable(items),
      Map.unmodifiable({
        for (var i = 0; i < totalCounts.length; i++)
          contentPerformanceColumns[i]: totalCounts[i],
      }),
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
  int countFor(ContentPerformanceMetric metric) => counts[metric.index];
  late final List<ContentPerformanceMetricValue> visibleMetrics =
      _nonZeroMetricValues(countFor);
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
    return ContentPerformanceItem._fromCounts(row, _ContentMetricCounts(row));
  }
  factory ContentPerformanceItem._fromCounts(
    Map<String, dynamic> row,
    _ContentMetricCounts metrics,
  ) {
    final starts = tryParseDateTimeValue(row['start_date'], toLocal: true);
    final ends = tryParseDateTimeValue(row['end_date'], toLocal: true);
    return ContentPerformanceItem._(
      Map.unmodifiable(row),
      parseStringValue(row['id']),
      parseStringValue(row['name']),
      parseStringValue(row['city']),
      row['is_approved'] == true,
      ends ?? starts,
      starts,
      ends,
      metrics.values,
      metrics.maximum,
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

/// Parse metric columns once, before deciding whether full row data is needed.
class _ContentMetricCounts {
  final List<int> values;
  final int maximum;
  final bool hasStatistics;
  _ContentMetricCounts._(this.values, this.maximum, this.hasStatistics);
  factory _ContentMetricCounts(Map<String, dynamic> row) {
    final values = <int>[];
    var maximum = 1;
    var hasStatistics = false;
    for (final column in contentPerformanceColumns) {
      final value = parseIntValue(row[column]);
      values.add(value);
      if (value != 0) hasStatistics = true;
      if (value > maximum) maximum = value;
    }
    return _ContentMetricCounts._(
      List<int>.unmodifiable(values),
      maximum,
      hasStatistics,
    );
  }
}
