import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/calendar/service_calendar_sharing.dart';
import 'package:life_pilot/game/model_game_user.dart';
import 'package:life_pilot/stock/model_stock.dart';
import 'package:life_pilot/subscription/model_subscription_usage.dart';
import 'package:life_pilot/vendor/model_vendor_account.dart';

void main() {
  test('vendor pricing accepts numeric text returned by an API', () {
    final plan = VendorPricingPlan.fromJson({
      'id': 'plan-1',
      'plan_code': 'growth',
      'version_name': '2026-Q4',
      'effective_at': '2026-10-01T00:00:00Z',
      'quarterly_price_twd': '258',
      'event_quota': '150',
      'attraction_quota': '40',
      'image_megabytes': '60',
      'analytics_days': '365',
    });

    expect(plan.quarterlyPriceTwd, 258);
    expect(plan.eventQuota, 150);
    expect(plan.attractionQuota, 40);
  });

  test('game history accepts text score, level, date, and pass state', () {
    final game = ModelGameUser.fromMap({
      'score': '88.5',
      'level': '3',
      'created_at': '2026-10-14T08:30:00Z',
      'is_pass': 't',
    });

    expect(game.score, 88.5);
    expect(game.level, 3);
    expect(game.createdAt, DateTime.utc(2026, 10, 14, 8, 30).toLocal());
    expect(game.isPass, isTrue);
  });

  test('subscription usage accepts bigint values represented as text', () {
    final usage = SubscriptionUsage.fromJson({
      'resource': 'calendar_events',
      'used': '12',
      'quota': '300',
    });

    expect(usage.used, 12);
    expect(usage.quota, 300);
  });

  test('stock models accept mixed database number representations', () {
    final stock = ModelStock.fromJson({
      'date': '2026-10-14',
      'security_code': '2330',
      'security_name': 'TSMC',
      'transactions_number': '1200',
      'closing_price': '1050.5',
      'signal': '2',
    });
    final future = ModelFuture.fromJson({'oi_net_qty': 42});

    expect(stock.transactionsNumber, 1200);
    expect(stock.closingPrice, 1050.5);
    expect(stock.signal, 2);
    expect(future.oiNetQty, 42);
  });

  test('calendar sharing accepts an existing DateTime value', () {
    final date = DateTime.utc(2026, 10, 14);
    final event = CalendarShareableEvent.fromJson({
      'id': 'event-1',
      'name': 'Shared event',
      'start_date': date,
    });

    expect(event.startDate, same(date));
  });
}
