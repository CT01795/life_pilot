import 'package:life_pilot/event/model_content_performance.dart';
import 'package:life_pilot/event/model_content_performance_period.dart';

/// Pure, immutable request projection, prepared once before reading any pages.
class ModelContentPerformanceQuery {
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
      if (statisticsOnly)
        contentPerformanceColumns.map((column) => '$column.neq.0').join(','),
    ];
    final filter = groups.isEmpty
        ? null
        : groups.length == 1
        ? groups.single
        : 'and(${groups.map((group) => 'or($group)').join(',')})';
    return ModelContentPerformanceQuery._(
      'id,name,is_approved,${contentPerformanceColumns.join(',')}'
      '${includeSubmissionDetails || period != null || statisticsOnly ? ',city,start_date,end_date' : ''}',
      filter,
    );
  }
}
