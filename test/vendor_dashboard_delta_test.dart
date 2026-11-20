import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/event/model_content_performance.dart';
import 'package:life_pilot/event/model_event_item.dart';
import 'package:life_pilot/vendor/model_vendor_account.dart';
import 'package:life_pilot/vendor/model_vendor_dashboard.dart';

void main() {
  final plan = VendorPricingPlan(
    id: 'plan',
    code: 'partner',
    versionName: 'current',
    effectiveAt: DateTime(2026),
    quarterlyPriceTwd: 499,
    eventQuota: 50,
    attractionQuota: 15,
    imageMegabytes: 25,
    analyticsDays: 365,
  );
  final performance = ModelContentPerformance(const []);

  ModelVendorDashboard dashboard() => ModelVendorDashboard(
    metrics: VendorContentMetrics(
      published: 2,
      pending: 1,
      activeEvents: 1,
      activeAttractions: 0,
      recentSubmissions: const [],
      performance: performance,
    ),
    status: VendorSubscriptionStatus(
      plan: plan,
      status: 'active',
      eventUsed: 1,
      attractionUsed: 0,
      imageBytesUsed: 0,
    ),
    plans: [plan],
  );

  test('editing a published active event updates only dashboard counters', () {
    final day = DateTime(2026, 11, 20);
    final result = dashboard().applySubmissionSaved(
      previous: EventItem(
        id: 'event',
        isApproved: true,
        endDate: day.add(const Duration(days: 1)),
        masterGraphUrl: 'old',
      ),
      current: EventItem(
        id: 'event',
        isApproved: false,
        endDate: day.subtract(const Duration(days: 1)),
        masterGraphUrl: 'longer',
      ),
      attraction: false,
      dayStart: day,
    );

    expect(result.metrics.published, 1);
    expect(result.metrics.pending, 2);
    expect(result.metrics.activeEvents, 0);
    expect(result.status.eventUsed, 0);
    expect(result.status.imageBytesUsed, 3);
    expect(result.metrics.performance, same(performance));
  });

  test('creating an active attraction increments pending and quota usage', () {
    final day = DateTime(2026, 11, 20);
    final result = dashboard().applySubmissionSaved(
      previous: null,
      current: EventItem(
        id: 'place',
        isApproved: false,
        endDate: day.add(const Duration(days: 30)),
      ),
      attraction: true,
      dayStart: day,
    );

    expect(result.metrics.published, 2);
    expect(result.metrics.pending, 2);
    expect(result.metrics.activeAttractions, 1);
    expect(result.status.attractionUsed, 1);
    expect(result.status.eventUsed, 1);
  });

  test('deleting an unreviewed event immediately removes its usage', () {
    final day = DateTime(2026, 11, 20);
    final result = dashboard().applySubmissionDeleted(
      previous: EventItem(
        id: 'event',
        isApproved: false,
        endDate: day.add(const Duration(days: 7)),
        masterGraphUrl: 'photo',
      ),
      attraction: false,
      dayStart: day,
    );

    expect(result.metrics.published, 2);
    expect(result.metrics.pending, 0);
    expect(result.metrics.activeEvents, 0);
    expect(result.status.eventUsed, 0);
    expect(result.status.imageBytesUsed, 0);
  });

  test('recent cards can be replaced without changing totals or plans', () {
    final recent = VendorRecentSubmission(
      id: 'new',
      name: 'New',
      city: 'Taipei',
      isActivity: true,
      isApproved: false,
    );
    final result = dashboard().withRecentSubmissions([recent]);

    expect(result.metrics.recentSubmissions, [same(recent)]);
    expect(result.metrics.published, 2);
    expect(result.status.eventUsed, 1);
    expect(result.plans, hasLength(1));
  });
}
