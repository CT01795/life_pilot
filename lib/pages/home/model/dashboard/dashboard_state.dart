import 'package:life_pilot/pages/home/model/accounting/income_expense_item.dart';
import 'package:life_pilot/pages/home/model/event/calendar_event.dart';
import 'package:life_pilot/pages/home/model/event/recommended_event.dart';
import 'package:life_pilot/pages/home/model/place/recommended_place.dart';
import 'package:life_pilot/pages/home/model/point/point_record_item.dart';

class DashboardState {
  final List<CalendarEvent> todayEvents;
  final List<RecommendedEvent> recommendEvents;
  final List<RecommendedPlace> recommendPlaces;
  final List<IncomeExpenseItem> todayIncomeExpense;
  final List<PointRecordItem> todayPoints;

  const DashboardState({
    required this.todayEvents,
    required this.recommendEvents,
    required this.recommendPlaces,
    required this.todayIncomeExpense,
    required this.todayPoints,
  });

  factory DashboardState.empty() {
    return const DashboardState(
      todayEvents: [],
      recommendEvents: [],
      recommendPlaces: [],
      todayIncomeExpense: [],
      todayPoints: [],
    );
  }

  DashboardState copyWith({
    List<CalendarEvent>? todayEvents,
    List<RecommendedEvent>? recommendEvents,
    List<RecommendedPlace>? recommendPlaces,
    List<IncomeExpenseItem>? todayIncomeExpense,
    List<PointRecordItem>? todayPoints,
  }){
    return DashboardState(
      todayEvents:
          todayEvents ?? this.todayEvents,
      recommendEvents:
          recommendEvents ?? this.recommendEvents,
      recommendPlaces:
          recommendPlaces ?? this.recommendPlaces,
      todayIncomeExpense:
          todayIncomeExpense ?? this.todayIncomeExpense,
      todayPoints:
          todayPoints ?? this.todayPoints,
    );
  }
}
