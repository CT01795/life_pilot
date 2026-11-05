import 'dart:async';
import 'package:life_pilot/event/model_content_performance.dart';
import 'package:life_pilot/event/model_content_performance_period.dart';
import 'package:life_pilot/utils/supabase.dart';

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
    required ContentPerformancePeriod period,
    String keyword = '',
    bool Function()? shouldContinue,
  }) async {
    if (shouldContinue?.call() == false) return ModelContentPerformance([]);
    final page = await readNextPage(
      owner: owner,
      attractions: attractions,
      period: period,
      keyword: keyword,
      offset: 0,
      shouldContinue: shouldContinue,
    );
    if (shouldContinue?.call() == false) return ModelContentPerformance([]);
    if (page == null) throw const FormatException('Missing performance page');
    return page;
  }

  Future<ModelContentPerformance?> readNextPage({
    required String owner,
    required bool attractions,
    required ContentPerformancePeriod period,
    required String keyword,
    required int offset,
    bool Function()? shouldContinue,
  }) async {
    if (shouldContinue?.call() == false) return null;
    final client = supabase;
    if (client.auth.currentUser?.email?.toLowerCase() != owner.toLowerCase()) {
      throw StateError('Account scope changed');
    }
    final month = period.month;
    final result = await client
        .rpc(
          'get_my_content_performance_page',
          params: {
            'p_attractions': attractions,
            'p_keyword': keyword.trim(),
            'p_unexpired': month == null,
            'p_from': (month ?? period.today).toUtc().toIso8601String(),
            'p_to': month == null
                ? null
                : DateTime(
                    month.year,
                    month.month + 1,
                  ).toUtc().toIso8601String(),
            'p_offset': offset,
            'p_limit': 20,
            'p_include_totals': offset == 0,
          },
        )
        .timeout(pageTimeout < totalTimeout ? pageTimeout : totalTimeout);
    if (shouldContinue?.call() == false) return null;
    if (client.auth.currentUser?.email?.toLowerCase() != owner.toLowerCase()) {
      throw StateError('Account scope changed');
    }
    if (result is! Map || result['items'] is! List) {
      throw const FormatException('Invalid performance page');
    }
    final page = Map<String, dynamic>.from(result);
    if (offset == 0 &&
        (page['items'] as List).isEmpty &&
        page['next_offset'] == null &&
        page['totals'] == null) {
      page['totals'] = const <String, dynamic>{};
    }
    if (offset == 0 && page['totals'] is! Map) {
      throw const FormatException('Performance summary is missing');
    }
    return ModelContentPerformance.fromPage(page, attractions: attractions);
  }
}
