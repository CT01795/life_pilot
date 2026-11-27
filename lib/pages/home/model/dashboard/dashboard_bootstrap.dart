import 'package:life_pilot/pages/home/model/accounting/income_expense_item.dart';
import 'package:life_pilot/pages/home/model/dashboard/dashboard_setting.dart';
import 'package:life_pilot/pages/home/model/event/calendar_event.dart';
import 'package:life_pilot/pages/home/model/point/point_record_item.dart';

/// The result belongs only to the refresh that requested it.
class DashboardBootstrap {
  const DashboardBootstrap({
    required this.setting,
    this.todayEvents,
    this.accounting,
    this.points,
    this.sharedLedgers,
  });

  final DashboardSetting setting;
  final List<CalendarEvent>? todayEvents;
  final AccountingDashboardSummary? accounting;
  final PointDashboardSummary? points;
  final List<Map<String, dynamic>>? sharedLedgers;
}
