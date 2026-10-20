import 'package:flutter/material.dart';
import 'package:life_pilot/event/model_content_performance.dart';
import 'package:life_pilot/l10n/app_localizations.dart';

/// Presentation stays in the view layer; the metric model has no UI dependency.
extension ContentPerformanceMetricPresentation on ContentPerformanceMetric {
  String label(AppLocalizations loc) => switch (this) {
    ContentPerformanceMetric.pageViews => loc.vendorAnalyticsPageViews,
    ContentPerformanceMetric.navigationClicks => loc.vendorAnalyticsCardClicks,
    ContentPerformanceMetric.registrationClicks =>
      loc.vendorAnalyticsRegistrationClicks,
    ContentPerformanceMetric.saves => loc.vendorAnalyticsSaves,
    ContentPerformanceMetric.likes => loc.vendorAnalyticsLikes,
    ContentPerformanceMetric.dislikes => loc.vendorAnalyticsDislikes,
  };

  IconData get icon => switch (this) {
    ContentPerformanceMetric.pageViews => Icons.visibility_outlined,
    ContentPerformanceMetric.navigationClicks => Icons.directions_outlined,
    ContentPerformanceMetric.registrationClicks => Icons.how_to_reg_outlined,
    ContentPerformanceMetric.saves => Icons.bookmark_border,
    ContentPerformanceMetric.likes => Icons.thumb_up_alt_outlined,
    ContentPerformanceMetric.dislikes => Icons.thumb_down_alt_outlined,
  };
}
