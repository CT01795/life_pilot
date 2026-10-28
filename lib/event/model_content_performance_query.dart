import 'package:life_pilot/event/model_content_performance.dart';
import 'package:life_pilot/event/model_content_performance_period.dart';

/// Pure, immutable request projection, prepared once before reading any pages.
class ModelContentPerformanceQuery {
  static final _baseColumns =
      'id,name,is_approved,${contentPerformanceColumns.join(',')}';
  static final _nonZeroMetrics = contentPerformanceColumns
      .map((column) => '$column.neq.0')
      .join(',');
  static const _detailColumns = ',city,start_date,end_date';
  final String columns;
  final String? filter;
  ModelContentPerformanceQuery._(this.columns, this.filter);
  factory ModelContentPerformanceQuery({
    bool includeSubmissionDetails = false,
    ContentPerformancePeriod? period,
    String keyword = '',
    bool statisticsOnly = false,
  }) {
    final groups = <String>[
      if (period != null) period.databaseFilter,
      if (keyword.trim().isNotEmpty) contentPerformanceSearchFilter(keyword),
      if (statisticsOnly) _nonZeroMetrics,
    ];
    final filter = groups.isEmpty
        ? null
        : groups.length == 1
        ? groups.single
        : 'and(${groups.map((group) => 'or($group)').join(',')})';
    return ModelContentPerformanceQuery._(
      '$_baseColumns'
      '${includeSubmissionDetails || period != null || statisticsOnly ? _detailColumns : ''}',
      filter,
    );
  }
}
