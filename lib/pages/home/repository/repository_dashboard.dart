import 'package:life_pilot/pages/home/model/accounting/income_expense_item.dart';
import 'package:life_pilot/pages/home/model/dashboard/dashboard_city.dart';
import 'package:life_pilot/pages/home/model/dashboard/dashboard_setting.dart';
import 'package:life_pilot/pages/home/model/event/calendar_event.dart';
import 'package:life_pilot/pages/home/model/event/recommended_event.dart';
import 'package:life_pilot/pages/home/model/place/recommended_place.dart';
import 'package:life_pilot/pages/home/model/point/point_record_item.dart';
import 'package:life_pilot/utils/api.dart';
import 'package:life_pilot/utils/const.dart';

class DashboardRepository {
  Future<List<CalendarEvent>> loadTodayEvents(String account) async {
    final now = DateTime.now();
    final today = DateTime(
      now.year,
      now.month,
      now.day,
    );

    final tomorrow = today.add(
      const Duration(days: 3),
    );

    final result = await supabase
        .from(TableNames.calendarEvents)
        .select()
        .eq(Fields.account, account)
        .gte(
          'start_date',
          today.toUtc().toIso8601String(),
        )
        .lt(
          'start_date',
          tomorrow.toUtc().toIso8601String(),
        )
        .order(
          'start_date',
          ascending: true,
        )
        .order(
          'start_time',
          ascending: true,
        );

    return (result as List)
        .map(
          (e) => CalendarEvent.fromJson(e),
        )
        .toList();
  }

  Future<List<CalendarEvent>> getSpecificEvent(
    String eventId,
    String account,
  ) async {
    final result = await supabase
        .from(TableNames.calendarEvents)
        .select()
        .eq(Fields.account, account)
        .eq(Fields.id, eventId)
        .order(
          'start_date',
          ascending: true,
        )
        .order(
          'start_time',
          ascending: true,
        );

    return (result as List)
        .map(
          (e) => CalendarEvent.fromJson(e),
        )
        .toList();
  }

  Future<void> completeEvent({
    required String id,
    required String account,
  }) async {
    await supabase
        .from(TableNames.calendarEvents)
        .update({
          'is_completed': true,
        })
        .eq(
          Fields.id,
          id,
        )
        .eq(
          Fields.account,
          account,
        );
  }

  //=====================================================================================================
  Future<DashboardSetting> loadDashboardSetting({
    required String account,
  }) async {
    final result = await supabase
        .from(TableNames.dashboardSetting)
        .select()
        .eq(Fields.account, account)
        .maybeSingle();

    if (result == null) {
      final setting = DashboardSetting(
          recommendEventCity: '台北', recommendPlaceCity: '台北', language: 'zh');

      await supabase.from('dashboard_setting').insert({
        Fields.account: account,
        ...setting.toJson(),
      });

      return setting;
    }

    return DashboardSetting.fromJson(result);
  }

  Future<void> saveDashboardSetting({
    required String account,
    required DashboardSetting setting,
  }) async {
    await supabase.from(TableNames.dashboardSetting).upsert({
      Fields.account: account,
      ...setting.toJson(),
    });
  }

  Future<List<DashboardCity>> loadEventCities() async {
    final result = await supabase.rpc('get_event_city_counts');

    return (result as List)
        .map(
          (e) => DashboardCity.fromJson(e),
        )
        .toList();
  }

  Future<List<RecommendedEvent>> loadRecommendEvents(String city) async {
    final result = await supabase.rpc(
      'get_home_recommended_events',
      params: {
        'p_city': city,
        'p_limit': 5,
      },
    );

    return (result as List)
        .map(
          (e) => RecommendedEvent.fromJson(e),
        )
        .toList();
  }

  Future<List<DashboardCity>> loadPlaceCities() async {
    final result = await supabase.rpc('get_place_city_counts');

    return (result as List)
        .map(
          (e) => DashboardCity.fromJson(e),
        )
        .toList();
  }

  Future<List<RecommendedPlace>> loadRecommendPlaces(String city) async {
    final result = await supabase.rpc(
      'get_home_recommended_places',
      params: {
        'p_city': city,
        'p_limit': 5,
      },
    );

    return (result as List)
        .map(
          (e) => RecommendedPlace.fromJson(e),
        )
        .toList();
  }

  Future<List<IncomeExpenseItem>> loadTodayIncomeExpense(
      {required String accountId}) async {
    final accountResult = await supabase
        .from(TableNames.accountingAccount)
        .select('id,main_currency')
        .eq(
          Fields.id,
          accountId,
        )
        .maybeSingle();

    if (accountResult == null) {
      return [];
    }
    //final accountId = accountResult[Fields.id];
    final currency = accountResult['main_currency'];
    final now = DateTime.now();
    final start = DateTime(
      now.year,
      now.month,
      now.day,
    );
    final end = start.add(
      const Duration(days: 1),
    );
    final result = await supabase
        .from(TableNames.accountingDetail)
        .select()
        .eq(
          'account_id',
          accountId,
        )
        .eq('currency', currency)
        .gte(
          'date',
          start.toUtc().toIso8601String(),
        )
        .lt(
          'date',
          end.toUtc().toIso8601String(),
        )
        .order('date', ascending: false);

    return (result as List)
        .map(
          (e) => IncomeExpenseItem.fromJson(e),
        )
        .toList();
  }

  Future<List<PointRecordItem>> loadPoints({required String accountId}) async {
    final accountResult = await supabase
        .from(TableNames.pointRecordAccount)
        .select(Fields.id)
        .eq(
          Fields.id,
          accountId,
        )
        .maybeSingle();

    if (accountResult == null) {
      return [];
    }
    //final accountId = accountResult[Fields.id];
    final now = DateTime.now();
    final start = DateTime(
      now.year,
      now.month,
      now.day,
    );
    final end = start.add(
      const Duration(days: 1),
    );
    final result = await supabase
        .from(TableNames.pointRecordDetail)
        .select()
        .eq(
          'account_id',
          accountId,
        )
        .gte(
          'date',
          start.toUtc().toIso8601String(),
        )
        .lt(
          'date',
          end.toUtc().toIso8601String(),
        )
        .order('date', ascending: false);

    return (result as List)
        .map(
          (e) => PointRecordItem.fromJson(e),
        )
        .toList();
  }
}
