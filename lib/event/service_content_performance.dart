import 'dart:async';
import 'package:life_pilot/event/model_content_performance.dart';
import 'package:life_pilot/event/model_content_performance_period.dart';
import 'package:life_pilot/event/model_content_performance_query.dart';
import 'package:life_pilot/utils/paged_row_reader.dart';
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
    bool Function()? shouldContinue,
  }) async {
    final projection = ModelContentPerformanceQuery(
      includeSubmissionDetails: includeSubmissionDetails,
      period: period,
      keyword: keyword,
      statisticsOnly: statisticsOnly,
    );
    final elapsed = Stopwatch()..start();
    final normalizedOwner = owner.toLowerCase();
    final rows = await readAllPagedRows(
      shouldContinue: shouldContinue,
      fetch: (offset, limit) async {
        if (supabase.auth.currentUser?.email?.toLowerCase() !=
            normalizedOwner) {
          throw StateError('Account scope changed');
        }
        var query = supabase
            .from(
              attractions
                  ? TableNames.recommendPlaces
                  : TableNames.recommendEvents,
            )
            .select(projection.columns)
            .eq('account', owner);
        final filters = projection.filter;
        if (filters != null) query = query.or(filters);
        var ordered = query.order(
          'end_date',
          ascending: true,
          nullsFirst: false,
        );
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
        return ordered
            .order('id', ascending: true, nullsFirst: false)
            .range(offset, offset + limit - 1)
            .timeout(timeout);
      },
    );
    return ModelContentPerformance(
      rows,
      sortByExpiry: true,
      attractions: attractions,
      statisticsOnly: statisticsOnly,
    );
  }
}
