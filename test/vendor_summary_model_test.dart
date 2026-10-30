import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/vendor/model_vendor_account.dart';
import 'package:life_pilot/event/model_content_performance.dart';

void main() {
  test(
    'compact summary retains global totals without downloading individual content',
    () {
      final source = {
        'published': 5000,
        'pending': 5000,
        'active_events': 10000,
        'active_attractions': 3,
        'totals': {'page_views': 10006, 'like_counts': 1000},
        'recent_submissions': List.generate(
          7,
          (i) => {
            'id': '$i',
            'name': 'Event $i',
            'city': 'City',
            'is_activity': true,
            'is_approved': false,
            'start_date': '2026-10-30T00:00:00Z',
          },
        ),
      };
      final metrics = VendorContentMetrics.fromSummary(source);
      expect(metrics.activeEvents, 10000);
      expect(metrics.published, 5000);
      expect(metrics.pending, 5000);
      expect(metrics.recentSubmissions, hasLength(5));
      expect(metrics.recentSubmissions.first.isActivity, true);
      expect(
        metrics.performance.totalFor(ContentPerformanceMetric.pageViews),
        10006,
      );
      expect(
        metrics.performance.totalFor(ContentPerformanceMetric.likes),
        1000,
      );
      expect(
        metrics.performance.totalFor(ContentPerformanceMetric.dislikes),
        0,
      );
      expect(metrics.performance.rows, isEmpty);
      expect(() => metrics.recentSubmissions.clear(), throwsUnsupportedError);
    },
  );
}
