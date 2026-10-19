import 'dart:async';
import 'package:life_pilot/event/model_content_performance.dart';
import 'package:life_pilot/event/model_content_performance_period.dart';
import 'package:life_pilot/utils/api.dart';
import 'package:life_pilot/utils/const.dart';

class ServiceContentPerformance {
  final Duration pageTimeout;
  final Duration totalTimeout;
  ServiceContentPerformance({
    this.pageTimeout = const Duration(seconds: 20),
    this.totalTimeout = const Duration(seconds: 30),
  });
  Future<ModelContentPerformance> read({
    required String owner,
    required bool attractions,
    bool includeSubmissionDetails = false,
    ContentPerformancePeriod? period,
    String keyword = '',
    bool statisticsOnly = false,
  }) async {
    final rows = <Map<String, dynamic>>[];
    final seen = <String>{};
    final elapsed = Stopwatch()..start();
    while (true) {
      if (supabase.auth.currentUser?.email?.toLowerCase() !=
          owner.toLowerCase()) {
        throw StateError('Account scope changed');
      }
      var query = supabase
          .from(
            attractions
                ? TableNames.recommendPlaces
                : TableNames.recommendEvents,
          )
          .select(
            'id,name,is_approved,${contentPerformanceColumns.join(',')}'
            '${includeSubmissionDetails || period != null || statisticsOnly ? ',city,start_date,end_date' : ''}',
          )
          .eq('account', owner);
      final search = keyword.trim().isEmpty
          ? null
          : contentPerformanceSearchFilter(keyword);
      final groups = <String>[];
      if (period != null) groups.add(period.databaseFilter);
      if (search != null) groups.add(search);
      if (statisticsOnly) {
        groups.add(
          contentPerformanceColumns.map((column) => '$column.neq.0').join(','),
        );
      }
      final filters = groups.isEmpty
          ? null
          : groups.length == 1
          ? groups.single
          : 'and(${groups.map((group) => 'or($group)').join(',')})';
      if (filters != null) query = query.or(filters);
      var ordered = query.order('end_date', ascending: true, nullsFirst: false);
      ordered = ordered.order('city', ascending: true, nullsFirst: false);
      ordered = ordered.order(
        'start_date',
        ascending: attractions,
        nullsFirst: false,
      );
      final remaining = totalTimeout - elapsed.elapsed;
      if (remaining <= Duration.zero) {
        throw TimeoutException(
          'Content performance query timed out',
          totalTimeout,
        );
      }
      final timeout = pageTimeout < remaining ? pageTimeout : remaining;
      final batch = await ordered
          .order('id', ascending: true, nullsFirst: false)
          .range(rows.length, rows.length + 499)
          .timeout(timeout);
      if (batch.isEmpty) break;
      for (final row in batch) {
        if (!seen.add(row['id'].toString())) {
          throw StateError('Repeated performance page');
        }
        rows.add(Map<String, dynamic>.from(row));
      }
    }
    return ModelContentPerformance(
      rows,
      sortByExpiry: true,
      attractions: attractions,
      statisticsOnly: statisticsOnly,
    );
  }
}
